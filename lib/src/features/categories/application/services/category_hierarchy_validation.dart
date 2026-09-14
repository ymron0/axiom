import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/categories/domain/enums/category_kind.dart';
import 'package:axiom/src/features/categories/domain/failures/category_failure.dart';
import 'package:axiom/src/features/categories/domain/failures/category_invalid_parent_failure.dart';
import 'package:axiom/src/features/categories/domain/failures/category_kind_mismatch_failure.dart';
import 'package:axiom/src/features/categories/domain/repositories/category_repository.dart';
import 'package:axiom/src/features/categories/domain/services/category_hierarchy_validator.dart';

/// Validates a category's prospective parent relationship before persistence.
abstract final class CategoryHierarchyValidation {
  /// Returns a failure when [parentCategoryId] cannot parent a category with
  /// [kind], including a self-parent relationship.
  static Future<Result<void, CategoryFailure>> validateParent({
    required CategoryRepository repository,
    required CategoryId? categoryId,
    required CategoryId? parentCategoryId,
    required CategoryKind kind,
  }) async {
    if (parentCategoryId == null) {
      return const Success(null);
    }
    if (parentCategoryId == categoryId) {
      return const CategoryInvalidParentFailure(
        message: 'A category cannot be its own parent.',
      );
    }

    final parentResult = await repository.getById(parentCategoryId);
    if (parentResult case final Failure<CategoryFailure> failure) {
      return failure;
    }

    final parent = parentResult.valueOrNull;
    if (parent == null) {
      return CategoryInvalidParentFailure(
        message: 'Parent category was not found: ${parentCategoryId.value}',
      );
    }
    if (parent.isArchived) {
      return CategoryInvalidParentFailure(
        message: 'Archived category cannot be a parent: ${parent.id.value}',
      );
    }
    if (parent.kind != kind) {
      return const CategoryKindMismatchFailure(
        message: 'A child category must have the same kind as its parent.',
      );
    }

    try {
      CategoryHierarchyValidator.validateParentChildRelationship(
        parent: parent,
        childKind: kind,
      );
    } on ArgumentError catch (error) {
      return CategoryInvalidParentFailure(message: error.message.toString());
    }

    return const Success(null);
  }
}
