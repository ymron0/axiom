import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_failure.dart';
import 'package:axiom/src/features/transactions/domain/repositories/transaction_repository.dart';

/// Creates and persists one active transaction.
final class CreateTransactionUseCase {
  /// Creates a use case backed by [repository].
  const CreateTransactionUseCase({required TransactionRepository repository})
    : _repository = repository; // ignore: prefer_initializing_formals

  final TransactionRepository _repository;

  /// Persists [transaction].
  ///
  /// Returns a [TransactionFailure] when persistence rejects the transaction.
  Future<Result<void, TransactionFailure>> call(Transaction transaction) {
    return _repository.create(transaction);
  }
}
