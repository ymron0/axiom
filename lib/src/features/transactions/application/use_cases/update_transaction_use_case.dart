import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_failure.dart';
import 'package:axiom/src/features/transactions/domain/repositories/transaction_repository.dart';

/// Replaces one active persisted transaction snapshot.
final class UpdateTransactionUseCase {
  /// Creates a use case backed by [repository].
  UpdateTransactionUseCase(this._repository);

  final TransactionRepository _repository;

  /// Replaces the persisted snapshot for [transaction] without incrementing
  /// its entity version.
  ///
  /// Returns a [TransactionFailure] when [transaction] is deleted, absent from
  /// persistence, or has a different entity version from the stored snapshot.
  Future<Result<void, TransactionFailure>> call(Transaction transaction) {
    return _repository.update(transaction);
  }
}
