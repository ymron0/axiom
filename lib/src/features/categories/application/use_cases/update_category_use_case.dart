import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/categories/application/services/category_hierarchy_validation.dart';
import 'package:axiom/src/features/categories/domain/entities/category.dart';
import 'package:axiom/src/features/categories/domain/failures/category_already_deleted_failure.dart';
import 'package:axiom/src/features/categories/domain/failures/category_failure.dart';
import 'package:axiom/src/features/categories/domain/failures/category_invalid_parent_failure.dart';
import 'package:axiom/src/features/categories/domain/failures/category_kind_mismatch_failure.dart';
import 'package:axiom/src/features/categories/domain/repositories/category_repository.dart';

/// Replaces one active persisted category snapshot.
final class UpdateCategoryUseCase {
  /// Creates a use case backed by [repository].
  UpdateCategoryUseCase(this._repository);

  final CategoryRepository _repository;

  /// Replaces the persisted snapshot for [category] after validating hierarchy.
  Future<Result<void, CategoryFailure>> call(Category category) async {
    if (category.isDeleted) {
      return CategoryAlreadyDeletedFailure(
        message: 'Deleted category cannot be updated: ${category.id.value}',
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

    final childrenResult = await _repository.getByParentId(category.id);
    if (childrenResult case final Failure<CategoryFailure> failure) {
      return failure;
    }

    final children = childrenResult.valueOrNull!;
    if (children.isNotEmpty && category.isChild) {
      return const CategoryInvalidParentFailure(
        message: 'A category with children cannot become a child category.',
      );
    }
    if (children.any((child) => child.kind != category.kind)) {
      return const CategoryKindMismatchFailure(
        message: 'A parent category must have the same kind as its children.',
      );
    }

    return _repository.update(category);
  }
}
