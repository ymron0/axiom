import 'package:axiom/src/core/identity/ids/merchant_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/application/use_cases/query_transactions_use_case.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_failure.dart';
import 'package:axiom/src/features/transactions/domain/repositories/transaction_query.dart';

/// Returns the number of transactions associated with a merchant during a
/// requested period.
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
/// ## Transaction semantics
///
/// All persisted transactions associated with [merchantId] participate,
/// regardless of kind or state.
///
/// Additional restrictions such as counting only actual transactions should be
/// applied explicitly by a separate reporting requirement rather than being
/// implied by this service.
///
/// ## Failure semantics
///
/// Transaction query failures are propagated unchanged.
final class GetMerchantTransactionCountService {
  final QueryTransactionsUseCase _queryTransactions;

  /// Creates a merchant transaction-count service.
  const GetMerchantTransactionCountService({
    required QueryTransactionsUseCase queryTransactions,
  }) : _queryTransactions = // ignore: prefer_initializing_formals
           queryTransactions;

  /// Returns the number of transactions associated with [merchantId] during
  /// `[effectiveFrom, effectiveUntil)`.
  Future<Result<int, TransactionFailure>> call(
    MerchantId merchantId, {
    required DateTime effectiveFrom,
    required DateTime effectiveUntil,
  }) async {
    final effectiveFromUtc = effectiveFrom.toUtc();
    final effectiveUntilUtc = effectiveUntil.toUtc();

    if (effectiveUntilUtc.isBefore(effectiveFromUtc)) {
      throw ArgumentError.value(
        effectiveUntil,
        'effectiveUntil',
        'Merchant transaction-count end time cannot precede its start time.',
      );
    }

    final result = await _queryTransactions(
      TransactionQuery(
        merchantIds: {merchantId},
        effectiveFrom: effectiveFromUtc,
        effectiveUntil: effectiveUntilUtc,
      ),
    );

    if (result case final Failure<TransactionFailure> failure) {
      return failure;
    }

    return Success(result.valueOrNull!.length);
  }
}
