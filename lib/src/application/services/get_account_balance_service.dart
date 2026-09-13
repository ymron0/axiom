import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/accounts/application/use_cases/get_account_by_id_use_case.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_not_found_failure.dart';
import 'package:axiom/src/features/accounts/domain/services/account_balance_calculator.dart';
import 'package:axiom/src/features/transactions/application/use_cases/get_ledger_entries_by_account_id_use_case.dart';
import 'package:decimal/decimal.dart';

/// Derives the current balance of a persisted account.
///
/// This service coordinates the Accounts and Transactions features. The
/// account supplies its denomination, the transaction lookup supplies its
/// ledger entries, and [AccountBalanceCalculator] performs the arithmetic.
///
/// ## Contract
///
/// Returns:
///
/// - the signed account balance on success;
/// - [AccountNotFoundFailure] when the account does not exist; or
/// - a failure returned by either feature use case.
final class GetAccountBalanceService {
  /// Creates an account balance service with its required dependencies.
  const GetAccountBalanceService({
    required GetAccountByIdUseCase getAccountById,
    required GetLedgerEntriesByAccountIdUseCase getLedgerEntriesByAccountId,
    required AccountBalanceCalculator calculator,
  }) : _getAccountById = getAccountById, // ignore: prefer_initializing_formals
       _getLedgerEntriesByAccountId = // ignore: prefer_initializing_formals
           getLedgerEntriesByAccountId,
       _calculator = calculator; // ignore: prefer_initializing_formals

  final GetAccountByIdUseCase _getAccountById;
  final GetLedgerEntriesByAccountIdUseCase _getLedgerEntriesByAccountId;
  final AccountBalanceCalculator _calculator;

  /// Returns the signed balance of the account identified by [accountId].
  Future<Result<Decimal, BaseFailure>> call(AccountId accountId) async {
    final accountResult = await _getAccountById(accountId);

    return accountResult.when<Future<Result<Decimal, BaseFailure>>>(
      success: (account) async {
        if (account == null) {
          return AccountNotFoundFailure(
            message: 'Account ID was not found: ${accountId.value}',
          );
        }

        final entriesResult = await _getLedgerEntriesByAccountId(account.id);

        return entriesResult.when<Result<Decimal, BaseFailure>>(
          success: (entries) => Success(
            _calculator.calculate(
              accountId: account.id,
              denominationAssetId: account.denominationAssetId,
              ledgerEntries: entries,
            ),
          ),
          failure: (failure) => failure,
        );
      },
      failure: (failure) async => failure,
    );
  }
}
