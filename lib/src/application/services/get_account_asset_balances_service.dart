import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/ports/clock/clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/accounts/application/use_cases/get_account_by_id_use_case.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_failure.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_not_found_failure.dart';
import 'package:axiom/src/features/accounts/domain/services/account_asset_balance_calculator.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/transactions/application/use_cases/get_transactions_by_account_id_use_case.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_state.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_failure.dart';

/// Returns the current per-asset balances held by one account.
///
/// Only actual transactions effective at or before the current instant
/// participate.
///
/// Planned transactions are excluded because they represent forecasts rather
/// than actual financial state.
///
/// Future-dated actual transactions are also excluded until their effective
/// instant is reached.
///
/// Zero net positions are omitted.
class GetAccountAssetBalancesService {
  final GetAccountByIdUseCase _getAccountById;
  final GetTransactionsByAccountIdUseCase _getTransactionsByAccountId;
  final AccountAssetBalanceCalculator _calculator;
  final Clock _clock;

  /// Creates the account asset-balance service.
  const GetAccountAssetBalancesService({
    required GetAccountByIdUseCase getAccountById,
    required GetTransactionsByAccountIdUseCase getTransactionsByAccountId,
    required AccountAssetBalanceCalculator calculator,
    required Clock clock,
  }) : _getAccountById = getAccountById, // ignore: prefer_initializing_formals
       _getTransactionsByAccountId = // ignore: prefer_initializing_formals
           getTransactionsByAccountId,
       _calculator = calculator, // ignore: prefer_initializing_formals
       _clock = clock; // ignore: prefer_initializing_formals

  /// Returns current non-zero asset balances for [accountId].
  Future<Result<List<AssetAmount>, BaseFailure>> call(
    AccountId accountId,
  ) async {
    final accountResult = await _getAccountById(accountId);

    if (accountResult case final Failure<AccountFailure> failure) {
      return failure;
    }

    final account = accountResult.valueOrNull;

    if (account == null) {
      return AccountNotFoundFailure(
        message: 'Account ID was not found: ${accountId.value}',
      );
    }

    final transactionsResult = await _getTransactionsByAccountId(account.id);

    if (transactionsResult case final Failure<TransactionFailure> failure) {
      return failure;
    }

    final nowUtc = _clock.nowUtc;

    final ledgerEntries = transactionsResult.valueOrNull!
        .where(
          (transaction) =>
              transaction.state == TransactionState.actual &&
              !transaction.effectiveAt.isAfter(nowUtc),
        )
        .expand((transaction) => transaction.ledgerEntries);

    return Success(
      _calculator.calculate(
        accountId: account.id,
        ledgerEntries: ledgerEntries,
      ),
    );
  }
}
