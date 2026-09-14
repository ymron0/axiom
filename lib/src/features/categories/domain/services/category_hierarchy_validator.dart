import 'package:axiom/src/features/categories/domain/entities/category.dart';
import 'package:axiom/src/features/categories/domain/enums/category_kind.dart';

/// Validates category relationships that require both child input and the
/// prospective parent entity.
///
/// These rules cannot be enforced by [Category] in isolation because the child
/// stores only the parent's identifier.
abstract final class CategoryHierarchyValidator {
  /// Validates whether [parent] may be used as the parent of a category whose
  /// financial nature is [childKind].
  ///
  /// Throws an [ArgumentError] when:
  ///
  /// - [parent] is itself a child category;
  /// - [parent] is deleted or archived; or
  /// - the parent and child have different category kinds.
  static void validateParentChildRelationship({
    required Category parent,
    required CategoryKind childKind,
  }) {
    if (parent.isChild) {
      throw ArgumentError.value(
        parent.id,
        'parent',
        'A child category cannot be the parent of another category.',
      );
    }

    if (parent.isDeleted) {
      throw ArgumentError.value(
        parent.id,
        'parent',
        'A deleted category cannot be used as a parent.',
      );
    }

    if (parent.isArchived) {
      throw ArgumentError.value(
        parent.id,
        'parent',
        'An archived category cannot be used as a parent.',
      );
    }

    if (parent.kind != childKind) {
      throw ArgumentError.value(
        childKind,
        'childKind',
        'A child category must have the same kind as its parent.',
      );
    }
  }
}
