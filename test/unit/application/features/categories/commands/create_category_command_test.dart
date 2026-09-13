import 'package:axiom/src/core/domain/enums/entity_color.dart';
import 'package:axiom/src/core/domain/enums/entity_icon.dart';
import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/features/categories/application/commands/create_category_command.dart';
import 'package:axiom/src/features/categories/domain/enums/category_kind.dart';
import 'package:test/test.dart';

void main() {
  group('CreateCategoryCommand', () {
    test('retains the supplied category creation input', () {
      // Given
      final parentId = CategoryId.fromString('household');

      // When
      final command = CreateCategoryCommand(
        name: 'Groceries',
        parentCategoryId: parentId,
        kind: CategoryKind.expense,
        icon: EntityIcon.payments,
        color: EntityColor.green,
        sortOrder: 3,
      );

      // Then
      expect(command.name, 'Groceries');
      expect(command.parentCategoryId, parentId);
      expect(command.kind, CategoryKind.expense);
      expect(command.budgets, isEmpty);
      expect(command.icon, EntityIcon.payments);
      expect(command.color, EntityColor.green);
      expect(command.sortOrder, 3);
    });
  });
}
