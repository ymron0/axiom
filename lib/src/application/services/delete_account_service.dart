import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/accounts/application/use_cases/delete_account_use_case.dart';
import 'package:axiom/src/features/accounts/domain/entities/account.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_in_use_failure.dart';
import 'package:axiom/src/features/transactions/application/use_cases/transactions_exist_by_account_id_use_case.dart';

/// Deletes an account when no persisted transaction references it.
///
/// This service coordinates the Accounts and Transactions features. It checks
/// transaction usage before delegating deletion to [DeleteAccountUseCase].
///
/// ## Invariants
///
/// - An account referenced by a persisted transaction is not deleted.
/// - Account deletion is delegated to [DeleteAccountUseCase].
/// - This service does not access feature repositories directly.
///
/// ## Contract
///
/// Returns:
///
/// - the deleted account snapshot on success;
/// - the failure returned while checking transaction usage;
/// - [AccountInUseFailure] when a transaction references the account;
/// - the failure returned while deleting the account.
final class DeleteAccountService {
  /// Creates an account deletion service.
  const DeleteAccountService({
    required TransactionsExistByAccountIdUseCase transactionsExist,
    required DeleteAccountUseCase deleteAccount,
  }) : _transactionsExist = // ignore: prefer_initializing_formals
           transactionsExist,
       _deleteAccount = deleteAccount; // ignore: prefer_initializing_formals

  final TransactionsExistByAccountIdUseCase _transactionsExist;
  final DeleteAccountUseCase _deleteAccount;

  /// Deletes the account identified by [accountId] when it is not in use.
  Future<Result<Account, BaseFailure>> call(AccountId accountId) async {
    final usageResult = await _transactionsExist(accountId);

    return usageResult.when<Future<Result<Account, BaseFailure>>>(
      success: (exists) async {
        if (exists) {
          return AccountInUseFailure(
            message: 'Account is referenced by a transaction: $accountId',
          );
        }

        return _deleteAccount(accountId);
      },
      failure: (failure) async => failure,
    );
  }
}
