import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_failure.dart';
import 'package:axiom/src/features/transactions/domain/repositories/transaction_repository.dart';

/// Restores a caller-retained, physically deleted snapshot as an active
/// transaction.
final class RestoreTransactionUseCase {
  /// Creates a use case backed by [repository].
  RestoreTransactionUseCase(this._repository);

  final TransactionRepository _repository;

  /// Restores [transaction] by storing a copy with its deleted state cleared.
  ///
  /// The supplied snapshot is not mutated. Returns a [TransactionFailure] when
  /// the snapshot is active already or its identity is already persisted.
  Future<Result<void, TransactionFailure>> call(Transaction transaction) {
    return _repository.restore(transaction);
  }
}
