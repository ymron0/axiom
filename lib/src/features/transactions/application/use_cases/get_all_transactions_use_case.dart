import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_failure.dart';
import 'package:axiom/src/features/transactions/domain/repositories/transaction_repository.dart';

/// Retrieves all active persisted transactions.
final class GetAllTransactionsUseCase {
  /// Creates a use case backed by [repository].
  GetAllTransactionsUseCase(this._repository);

  final TransactionRepository _repository;

  /// Returns all active persisted transactions.
  ///
  /// The result is an empty list when none exist, or a [TransactionFailure]
  /// when retrieval fails.
  Future<Result<List<Transaction>, TransactionFailure>> call() {
    return _repository.getAll();
  }
}
