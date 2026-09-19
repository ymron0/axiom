import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_failure.dart';
import 'package:axiom/src/features/transactions/domain/repositories/transaction_repository.dart';

/// Atomically persists one validated transaction offset.
final class CreateTransactionOffsetUseCase {
  /// Creates a use case backed by [repository].
  const CreateTransactionOffsetUseCase({
    required TransactionRepository repository,
  }) : _repository = repository; // ignore: prefer_initializing_formals

  final TransactionRepository _repository;

  /// Atomically validates and persists [transaction] as an offset.
  Future<Result<void, TransactionFailure>> call(Transaction transaction) {
    return _repository.createOffset(transaction);
  }
}
