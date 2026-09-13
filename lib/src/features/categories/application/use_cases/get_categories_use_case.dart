import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/categories/domain/entities/category.dart';
import 'package:axiom/src/features/categories/domain/failures/category_failure.dart';
import 'package:axiom/src/features/categories/domain/repositories/category_repository.dart';

/// Retrieves all active persisted categories.
final class GetCategoriesUseCase {
  /// Creates a use case backed by [repository].
  GetCategoriesUseCase(this._repository);

  final CategoryRepository _repository;

  /// Returns all active persisted categories.
  Future<Result<List<Category>, CategoryFailure>> call() {
    return _repository.getAll();
  }
}
