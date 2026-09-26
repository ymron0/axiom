import 'package:axiom/src/application/services/build_transaction_ledger_entry_service.dart';
import 'package:axiom/src/application/services/create_transaction_service.dart';
import 'package:axiom/src/application/services/get_account_balance_service.dart';
import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/merchant_id.dart';
import 'package:axiom/src/core/ports/clock/clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/accounts/application/use_cases/get_account_by_id_use_case.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_not_found_failure.dart';
import 'package:axiom/src/features/assets/domain/enums/asset_amount_direction.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/transactions/application/commands/create_transaction_command.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_kind.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_state.dart';
import 'package:decimal/decimal.dart';

/// Sets an account's initial balance through a balance-correction transaction.
///
/// ## Financial semantics
///
/// [targetBalance] is the desired signed account balance, not a delta.
///
/// The service derives the current balance and records only the difference:
///
/// `correction = target balance - current balance`
///
/// Positive corrections create an incoming ledger movement. Negative
/// corrections create an outgoing movement.
///
/// A zero correction creates no transaction.
///
/// ## Invariants
///
/// - The account must exist.
/// - The correction is expressed in the account denomination asset.
/// - Account and valuation representations are produced by
///   [BuildTransactionLedgerEntryService].
/// - The resulting transaction is an actual balance correction.
/// - No external merchant is involved, so [MerchantId.self] is used.
///
/// ## Contract
///
/// The operation is idempotent with respect to a target balance. Repeating the
/// operation after the target balance has already been reached creates no
/// additional financial movement.
final class CreateInitialBalanceService {
  /// Creates the service.
  const CreateInitialBalanceService({
    required GetAccountByIdUseCase getAccountById,
    required GetAccountBalanceService getAccountBalance,
    required BuildTransactionLedgerEntryService buildLedgerEntry,
    required CreateTransactionService createTransaction,
    required Clock clock,
  }) : _getAccountById = getAccountById, // ignore: prefer_initializing_formals
       _getAccountBalance = // ignore: prefer_initializing_formals
           getAccountBalance,
       _buildLedgerEntry = // ignore: prefer_initializing_formals
           buildLedgerEntry,
       _createTransaction = // ignore: prefer_initializing_formals
           createTransaction,
       _clock = clock; // ignore: prefer_initializing_formals

  final GetAccountByIdUseCase _getAccountById;
  final GetAccountBalanceService _getAccountBalance;
  final BuildTransactionLedgerEntryService _buildLedgerEntry;
  final CreateTransactionService _createTransaction;
  final Clock _clock;

  /// Sets [accountId] to [targetBalance].
  ///
  /// Returns the created balance-correction transaction, or `null` when the
  /// account already has the requested balance.
  Future<Result<Transaction?, BaseFailure>> call({
    required AccountId accountId,
    required Decimal targetBalance,
  }) async {
    final accountResult = await _getAccountById(accountId);

    if (accountResult case final Failure<BaseFailure> failure) {
      return failure;
    }

    final account = accountResult.valueOrNull;

    if (account == null) {
      return AccountNotFoundFailure(
        message: 'Account ID was not found: ${accountId.value}',
      );
    }

    final balanceResult = await _getAccountBalance(accountId);

    if (balanceResult case final Failure<BaseFailure> failure) {
      return failure;
    }

    final currentBalance = balanceResult.valueOrNull!;
    final correction = targetBalance - currentBalance;

    if (correction == Decimal.zero) {
      return const Success<Transaction?>(null);
    }

    final direction = correction < Decimal.zero
        ? AssetAmountDirection.outgoing
        : AssetAmountDirection.incoming;

    final transactionAmount = AssetAmount(
      assetId: account.denominationAssetId,
      amount: correction.abs(),
      direction: direction,
    );

    final effectiveAt = _clock.nowUtc;

    final entryResult = await _buildLedgerEntry(
      accountId: accountId,
      transactionAmount: transactionAmount,
      effectiveAt: effectiveAt,
    );

    if (entryResult case final Failure<BaseFailure> failure) {
      return failure;
    }

    final createResult = await _createTransaction(
      CreateTransactionCommand(
        kind: TransactionKind.balanceCorrection,
        merchantId: MerchantId.self,
        effectiveAt: effectiveAt,
        description: 'Initial balance',
        state: TransactionState.actual,
        tagIds: const [],
        splits: const [],
        ledgerEntries: [entryResult.valueOrNull!],
      ),
    );

    return createResult.when<Result<Transaction?, BaseFailure>>(
      success: (transaction) => Success<Transaction?>(transaction),
      failure: (failure) => failure,
    );
  }
}
