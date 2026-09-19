import 'package:axiom/src/core/identity/ids/tag_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_failure.dart';
import 'package:axiom/src/features/transactions/domain/repositories/transaction_repository.dart';

/// Determines whether a tag is referenced by any persisted transaction.
final class TransactionsExistByTagIdUseCase {
  final TransactionRepository _repository;

  /// Creates a tag-reference existence query.
  TransactionsExistByTagIdUseCase(this._repository);

  /// Returns whether any persisted transaction references [tagId].
  Future<Result<bool, TransactionFailure>> call(TagId tagId) {
    return _repository.existsByTagId(tagId);
  }
}
