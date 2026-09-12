import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_failure.dart';
import 'package:axiom/src/features/transactions/domain/repositories/transaction_repository.dart';

/// Atomically creates and stores multiple active transactions.
///
/// If any transaction cannot be stored, none of the transactions are stored.
final class CreateAllTransactionsUseCase {
  /// Creates a use case backed by [repository].
  CreateAllTransactionsUseCase(this._repository);

  final TransactionRepository _repository;

  /// Stores every transaction in [transactions] as one atomic operation.
  ///
  /// Returns success, including for an empty list, or a [TransactionFailure]
  /// without storing any transaction from the batch when the operation cannot
  /// complete.
  Future<Result<void, TransactionFailure>> call(
    List<Transaction> transactions,
  ) {
    return _repository.createAll(transactions);
  }
}
