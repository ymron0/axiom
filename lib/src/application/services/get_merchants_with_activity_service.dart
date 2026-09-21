import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/identity/ids/merchant_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/merchants/application/use_cases/get_merchants_use_case.dart';
import 'package:axiom/src/features/merchants/domain/entities/merchant.dart';
import 'package:axiom/src/features/merchants/domain/failures/merchant_failure.dart';
import 'package:axiom/src/features/merchants/domain/failures/merchant_not_found_failure.dart';
import 'package:axiom/src/features/transactions/application/use_cases/query_transactions_use_case.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_state.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_failure.dart';
import 'package:axiom/src/features/transactions/domain/repositories/transaction_query.dart';

/// Returns merchants that had actual transaction activity during a period.
///
/// This service coordinates the Transactions and Merchants features without
/// accessing either feature's repository directly.
///
/// ## Period semantics
///
/// [effectiveFrom] is inclusive.
///
/// [effectiveUntil] is exclusive.
///
/// Both boundaries are normalized to UTC before querying transactions.
///
/// An empty period, where both boundaries are equal, is valid.
///
/// ## Activity semantics
///
/// Only actual transactions count as merchant activity.
///
/// Planned transactions are excluded because they represent expected future
/// activity rather than activity that has occurred.
///
/// [MerchantId.self] is excluded because it represents the absence of a
/// persisted merchant and is used by transactions such as transfers and
/// balance corrections.
///
/// Multiple transactions referencing the same merchant produce only one
/// merchant in the result.
///
/// Archived merchants remain eligible because historical transactions may
/// legitimately reference merchants that are no longer active.
///
/// ## Ordering
///
/// Returned merchants preserve the ordering supplied by
/// [GetMerchantsUseCase].
///
/// ## Failure semantics
///
/// Returns:
///
/// - the merchants that had activity during the requested period;
/// - an empty list when no persisted merchant had activity;
/// - transaction failures propagated unchanged;
/// - merchant failures propagated unchanged; or
/// - [MerchantNotFoundFailure] when a transaction references a non-self
///   merchant that cannot be resolved.
///
/// An unresolved merchant reference indicates inconsistent persisted data and
/// is not silently omitted.
final class GetMerchantsWithActivityService {
  final QueryTransactionsUseCase _queryTransactions;
  final GetMerchantsUseCase _getMerchants;

  /// Creates the merchant-activity service.
  const GetMerchantsWithActivityService({
    required QueryTransactionsUseCase queryTransactions,
    required GetMerchantsUseCase getMerchants,
  }) : _queryTransactions = // ignore: prefer_initializing_formals
           queryTransactions,
       _getMerchants = // ignore: prefer_initializing_formals
           getMerchants;

  /// Returns merchants with actual activity in
  /// `[effectiveFrom, effectiveUntil)`.
  Future<Result<List<Merchant>, BaseFailure>> call({
    required DateTime effectiveFrom,
    required DateTime effectiveUntil,
  }) async {
    final effectiveFromUtc = effectiveFrom.toUtc();
    final effectiveUntilUtc = effectiveUntil.toUtc();

    if (effectiveUntilUtc.isBefore(effectiveFromUtc)) {
      throw ArgumentError.value(
        effectiveUntil,
        'effectiveUntil',
        'Merchant activity end time cannot precede its start time.',
      );
    }

    final transactionsResult = await _queryTransactions(
      TransactionQuery(
        states: {TransactionState.actual},
        effectiveFrom: effectiveFromUtc,
        effectiveUntil: effectiveUntilUtc,
      ),
    );

    if (transactionsResult case final Failure<TransactionFailure> failure) {
      return failure;
    }

    final merchantIds = <MerchantId>{};

    for (final transaction in transactionsResult.valueOrNull!) {
      if (!transaction.merchantId.isSelf) {
        merchantIds.add(transaction.merchantId);
      }
    }

    if (merchantIds.isEmpty) {
      return const Success<List<Merchant>>([]);
    }

    final merchantsResult = await _getMerchants();

    if (merchantsResult case final Failure<MerchantFailure> failure) {
      return failure;
    }

    final merchants = merchantsResult.valueOrNull!;

    final resolvedMerchantIds = <MerchantId>{
      for (final merchant in merchants) merchant.id,
    };

    for (final merchantId in merchantIds) {
      if (!resolvedMerchantIds.contains(merchantId)) {
        return MerchantNotFoundFailure(
          message:
              'Transaction activity references a merchant that was not found: '
              '${merchantId.value}',
        );
      }
    }

    return Success(
      List<Merchant>.unmodifiable(
        merchants.where((merchant) => merchantIds.contains(merchant.id)),
      ),
    );
  }
}
