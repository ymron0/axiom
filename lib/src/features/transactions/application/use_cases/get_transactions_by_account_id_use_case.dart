import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_failure.dart';
import 'package:axiom/src/features/transactions/domain/repositories/transaction_repository.dart';

/// Retrieves transactions affecting one account.
class GetTransactionsByAccountIdUseCase {
  final TransactionRepository _repository;

  /// Creates a use case backed by [repository].
  const GetTransactionsByAccountIdUseCase(this._repository);

  /// Returns transactions containing at least one ledger entry for [accountId].
  ///
  /// Transaction lifecycle filtering is deliberately left to the caller
  /// because planned transactions may be useful to forecasting workflows.
  Future<Result<List<Transaction>, TransactionFailure>> call(
    AccountId accountId,
  ) {
    return _repository.getTransactionsByAccountId(accountId);
  }
}
