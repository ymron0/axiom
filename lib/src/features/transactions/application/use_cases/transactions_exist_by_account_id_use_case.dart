import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_failure.dart';
import 'package:axiom/src/features/transactions/domain/repositories/transaction_repository.dart';

/// Determines whether persisted transactions affect an account.
class TransactionsExistByAccountIdUseCase {
  /// Creates a use case backed by [repository].
  TransactionsExistByAccountIdUseCase(this._repository);

  final TransactionRepository _repository;

  /// Whether at least one persisted transaction affects [accountId].
  Future<Result<bool, TransactionFailure>> call(AccountId accountId) {
    return _repository.existsByAccountId(accountId);
  }
}
