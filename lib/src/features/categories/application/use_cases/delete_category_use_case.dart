import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/categories/domain/entities/category.dart';
import 'package:axiom/src/features/categories/domain/failures/category_failure.dart';
import 'package:axiom/src/features/categories/domain/repositories/category_repository.dart';

/// Physically deletes a category and returns its deleted snapshot.
final class DeleteCategoryUseCase {
  /// Creates a use case backed by [repository].
  DeleteCategoryUseCase(this._repository);

  final CategoryRepository _repository;

  /// Deletes the category identified by [id].
  Future<Result<Category, CategoryFailure>> call(CategoryId id) {
    return _repository.delete(id);
  }
}
