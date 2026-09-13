import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/categories/application/services/category_hierarchy_validation.dart';
import 'package:axiom/src/features/categories/domain/entities/category.dart';
import 'package:axiom/src/features/categories/domain/failures/category_already_active_failure.dart';
import 'package:axiom/src/features/categories/domain/failures/category_failure.dart';
import 'package:axiom/src/features/categories/domain/repositories/category_repository.dart';

/// Restores a caller-retained, physically deleted category snapshot.
final class RestoreCategoryUseCase {
  /// Creates a use case backed by [repository].
  RestoreCategoryUseCase(this._repository);

  final CategoryRepository _repository;

  /// Restores [category] as an active persisted category.
  Future<Result<void, CategoryFailure>> call(Category category) async {
    if (!category.isDeleted) {
      return CategoryAlreadyActiveFailure(
        message: 'Category is already active: ${category.id.value}',
      );
    }

    final hierarchyResult = await CategoryHierarchyValidation.validateParent(
      repository: _repository,
      categoryId: category.id,
      parentCategoryId: category.parentCategoryId,
      kind: category.kind,
    );
    if (hierarchyResult case final Failure<CategoryFailure> failure) {
      return failure;
    }

    return _repository.restore(category);
  }
}
