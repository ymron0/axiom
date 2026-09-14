@Tags(['domain'])
library;

import 'package:axiom/src/core/domain/enums/entity_color.dart';
import 'package:axiom/src/core/domain/enums/entity_icon.dart';
import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/features/categories/domain/entities/category.dart';
import 'package:axiom/src/features/categories/domain/enums/category_kind.dart';
import 'package:axiom/src/features/categories/domain/services/category_hierarchy_validator.dart';
import 'package:test/test.dart';

void main() {
  group('CategoryHierarchyValidator.validateParentChildRelationship', () {
    test('accepts an active top-level parent with the same kind', () {
      expect(
        () => CategoryHierarchyValidator.validateParentChildRelationship(
          parent: _category(),
          childKind: CategoryKind.expense,
        ),
        returnsNormally,
      );
    });

    test('rejects a parent that is itself a child', () {
      expect(
        () => CategoryHierarchyValidator.validateParentChildRelationship(
          parent: _category(parentCategoryId: CategoryId.fromString('root')),
          childKind: CategoryKind.expense,
        ),
        throwsA(isA<ArgumentError>().having((e) => e.name, 'name', 'parent')),
      );
    });

    test('rejects a deleted parent', () {
      expect(
        () => CategoryHierarchyValidator.validateParentChildRelationship(
          parent: _category(deletedAt: DateTime.utc(2026, 9, 13)),
          childKind: CategoryKind.expense,
        ),
        throwsA(isA<ArgumentError>().having((e) => e.name, 'name', 'parent')),
      );
    });

    test('rejects an archived parent', () {
      expect(
        () => CategoryHierarchyValidator.validateParentChildRelationship(
          parent: _category(archivedAt: DateTime.utc(2026, 9, 12)),
          childKind: CategoryKind.expense,
        ),
        throwsA(isA<ArgumentError>().having((e) => e.name, 'name', 'parent')),
      );
    });

    test('rejects a parent with a different kind', () {
      expect(
        () => CategoryHierarchyValidator.validateParentChildRelationship(
          parent: _category(kind: CategoryKind.income),
          childKind: CategoryKind.expense,
        ),
        throwsA(
          isA<ArgumentError>().having((e) => e.name, 'name', 'childKind'),
        ),
      );
    });
  });
}

Category _category({
  CategoryId? parentCategoryId,
  CategoryKind kind = CategoryKind.expense,
  DateTime? deletedAt,
  DateTime? archivedAt,
}) {
  final createdAt = DateTime.utc(2026, 9, 12);
  return Category(
    id: CategoryId.fromString('parent'),
    name: 'Parent',
    parentCategoryId: parentCategoryId,
    kind: kind,
    icon: EntityIcon.accountBalance,
    color: EntityColor.blue,
    sortOrder: 0,
    archivedAt: archivedAt,
    deletedAt: deletedAt,
    createdAt: createdAt,
    modifiedAt: createdAt,
    entityVersion: 1,
  );
}
