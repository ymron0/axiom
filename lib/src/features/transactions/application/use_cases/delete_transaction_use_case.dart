import 'package:axiom/src/core/identity/ids/transaction_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_failure.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_not_found_failure.dart';
import 'package:axiom/src/features/transactions/domain/repositories/transaction_repository.dart';

/// Physically deletes a transaction and returns a snapshot for restoration.
///
/// The repository does not retain the snapshot. The returned transaction is a
/// caller-owned copy marked with [Transaction.deletedAt] before the persisted
/// record is removed.
final class DeleteTransactionUseCase {
  /// Creates a use case backed by [repository].
  DeleteTransactionUseCase(this._repository);

  final TransactionRepository _repository;

  /// Looks up and physically deletes [id], returning its snapshot marked with
  /// [deletedAt].
  ///
  /// The returned snapshot is not persisted and can be supplied to
  /// `RestoreTransactionUseCase` later. Returns [TransactionNotFoundFailure]
  /// when [id] is not persisted, or the repository's [TransactionFailure]
  /// when the lookup or deletion fails.
  ///
  /// Throws [ArgumentError] when [deletedAt] precedes the transaction's
  /// creation time.
  Future<Result<Transaction, TransactionFailure>> call(
    TransactionId id,
    DateTime deletedAt,
  ) async {
    final lookup = await _repository.getById(id);
    if (lookup case final Failure<TransactionFailure> failure) {
      return failure;
    }

    final transaction = lookup.valueOrNull;
    if (transaction == null) {
      return TransactionNotFoundFailure(
        message: 'Transaction ID was not found: ${id.value}',
      );
    }

    final deleted = transaction.copyWith(deletedAt: deletedAt);
    final removal = await _repository.delete(id);
    if (removal case final Failure<TransactionFailure> failure) {
      return failure;
    }

    return Success(deleted);
  }
}
