import 'package:axiom/src/core/identity/ids/tag_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_failure.dart';
import 'package:axiom/src/features/transactions/domain/repositories/transaction_repository.dart';

/// Returns transactions referencing one tag.
final class GetTransactionsByTagIdUseCase {
  final TransactionRepository _repository;

  /// Creates a transaction-by-tag query use case.
  GetTransactionsByTagIdUseCase(this._repository);

  /// Returns transactions whose tag collection contains [tagId].
  Future<Result<List<Transaction>, TransactionFailure>> call(TagId tagId) {
    return _repository.getTransactionsByTagId(tagId);
  }
}
