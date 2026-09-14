import 'package:axiom/src/core/domain/enums/entity_color.dart';
import 'package:axiom/src/core/domain/enums/entity_icon.dart';
import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/features/categories/domain/entities/category.dart';
import 'package:axiom/src/features/categories/domain/enums/category_kind.dart';

/// Creates a valid category snapshot for tests.
Category categoryFixture({
  required String id,
  String name = 'Test Category',
  String? parentCategoryId,
  CategoryKind kind = CategoryKind.expense,
  EntityIcon icon = EntityIcon.other,
  EntityColor color = EntityColor.blue,
  int sortOrder = 0,
  DateTime? archivedAt,
  DateTime? deletedAt,
  DateTime? modifiedAt,
}) {
  final createdAt = DateTime.utc(2026, 1, 1);
  return Category(
    id: CategoryId.fromString(id),
    name: name,
    parentCategoryId: parentCategoryId == null
        ? null
        : CategoryId.fromString(parentCategoryId),
    kind: kind,
    icon: icon,
    color: color,
    sortOrder: sortOrder,
    archivedAt: archivedAt,
    deletedAt: deletedAt,
    createdAt: createdAt,
    modifiedAt: modifiedAt ?? createdAt,
    entityVersion: 1,
  );
}
