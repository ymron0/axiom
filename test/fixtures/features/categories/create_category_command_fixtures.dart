import 'package:axiom/src/core/domain/enums/entity_color.dart';
import 'package:axiom/src/core/domain/enums/entity_icon.dart';
import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/features/categories/application/commands/create_category_command.dart';
import 'package:axiom/src/features/categories/domain/enums/category_kind.dart';

/// Creates valid category creation input for tests.
CreateCategoryCommand createCategoryCommandFixture({
  String name = 'Test Category',
  String? parentCategoryId,
  CategoryKind kind = CategoryKind.expense,
  EntityIcon icon = EntityIcon.other,
  EntityColor color = EntityColor.blue,
  int sortOrder = 0,
}) {
  return CreateCategoryCommand(
    name: name,
    parentCategoryId: parentCategoryId == null
        ? null
        : CategoryId.fromString(parentCategoryId),
    kind: kind,
    icon: icon,
    color: color,
    sortOrder: sortOrder,
  );
}
