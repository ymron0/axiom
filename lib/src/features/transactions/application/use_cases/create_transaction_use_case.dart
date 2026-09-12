import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_failure.dart';
import 'package:axiom/src/features/transactions/domain/repositories/transaction_repository.dart';

/// Creates and stores one active transaction through the repository.
final class CreateTransactionUseCase {
  /// Creates a use case backed by [repository].
  CreateTransactionUseCase(this._repository);

  final TransactionRepository _repository;

  /// Stores [transaction].
  ///
  /// Returns a [TransactionFailure] when [transaction] is deleted or its
  /// identity conflicts with a persisted transaction.
  Future<Result<void, TransactionFailure>> call(Transaction transaction) {
    return _repository.create(transaction);
  }
}
