import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_failure.dart';
import 'package:axiom/src/features/transactions/domain/repositories/transaction_repository.dart';

/// Determines whether persisted transactions use a category.
final class TransactionsExistByCategoryIdUseCase {
  /// Creates a use case backed by [repository].
  TransactionsExistByCategoryIdUseCase(this._repository);

  final TransactionRepository _repository;

  /// Whether at least one persisted transaction references [categoryId].
  Future<Result<bool, TransactionFailure>> call(CategoryId categoryId) {
    return _repository.existsByCategoryId(categoryId);
  }
}
