import 'package:axiom/src/core/domain/enums/entity_color.dart';
import 'package:axiom/src/core/domain/enums/entity_icon.dart';
import 'package:axiom/src/core/domain/value_objects/calendar_date.dart';
import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/features/categories/domain/entities/category.dart';
import 'package:axiom/src/features/categories/domain/enums/budget_period.dart';
import 'package:axiom/src/features/categories/domain/enums/category_kind.dart';
import 'package:axiom/src/features/categories/domain/value_objects/category_budget.dart';
import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

void main() {
  group('Category', () {
    test('creates a category with normalized text and deterministic metadata', () {
      final timestamp = DateTime.parse('2026-09-12T10:30:00+02:00');

      final category = Category.create(
        name: '  Groceries  ',
        kind: CategoryKind.expense,
        icon: EntityIcon.storefront,
        color: EntityColor.green,
        sortOrder: 2,
        clock: FixedClock(timestamp),
      );

      expect(category.id.value, isNotEmpty);
      expect(category.name, 'Groceries');
      expect(category.kind, CategoryKind.expense);
      expect(category.sortOrder, 2);
      expect(category.entityVersion, 1);
      expect(category.createdAt, timestamp.toUtc());
      expect(category.modifiedAt, category.createdAt);
      expect(category.deletedAt, isNull);
      expect(category.isTopLevel, isTrue);
      expect(category.isChild, isFalse);
      expect(category.hasBudget, isFalse);
    });

    test('uses the default clock when none is supplied', () {
      final category = Category.create(
        name: 'Groceries',
        kind: CategoryKind.expense,
        icon: EntityIcon.storefront,
        color: EntityColor.green,
        sortOrder: 0,
      );

      expect(category.createdAt, isNotNull);
      expect(category.modifiedAt, category.createdAt);
    });

    test('reports a category with a parent as a child', () {
      final category = _category(parentCategoryId: CategoryId.fromString('parent'));

      expect(category.isChild, isTrue);
      expect(category.isTopLevel, isFalse);
    });

    test('rejects blank names and negative sort orders', () {
      expect(
        () => _category(name: '  '),
        throwsA(isA<ArgumentError>().having((e) => e.name, 'name', 'name')),
      );
      expect(
        () => _category(sortOrder: -1),
        throwsA(
          isA<ArgumentError>()
              .having((e) => e.name, 'name', 'sortOrder')
              .having((e) => e.invalidValue, 'invalidValue', -1),
        ),
      );
    });

    test('rejects deletion before creation and invalid audit metadata', () {
      final createdAt = DateTime.utc(2026, 9, 12);
      expect(
        () => _category(
          createdAt: createdAt,
          deletedAt: createdAt.subtract(const Duration(seconds: 1)),
        ),
        throwsA(isA<ArgumentError>().having((e) => e.name, 'name', 'deletedAt')),
      );
      expect(
        () => _category(entityVersion: 0),
        throwsA(isA<ArgumentError>().having((e) => e.name, 'name', 'entityVersion')),
      );
      expect(
        () => _category(
          createdAt: createdAt,
          modifiedAt: createdAt.subtract(const Duration(seconds: 1)),
        ),
        throwsA(isA<ArgumentError>().having((e) => e.name, 'name', 'modifiedAt')),
      );
    });

    test('validates budget ordering and overlap', () {
      final first = _budget(
        from: CalendarDate(2026, 1, 1),
        until: CalendarDate(2026, 4, 1),
      );
      final second = _budget(
        from: CalendarDate(2026, 4, 1),
        until: CalendarDate(2026, 7, 1),
      );

      expect(_category(budgets: [second, first]).budgets, [second, first]);
      expect(
        () => _category(
          budgets: [
            first,
            _budget(
              from: CalendarDate(2026, 3, 1),
              until: CalendarDate(2026, 5, 1),
            ),
          ],
        ),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => _category(
          budgets: [
            first,
            _budget(from: CalendarDate(2026, 8, 1)),
          ],
        ),
        returnsNormally,
      );
      expect(
        () => _category(
          budgets: [
            _budget(from: CalendarDate(2026, 1, 1)),
            second,
          ],
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('returns the budget effective at a date', () {
      final historical = _budget(
        from: CalendarDate(2026, 1, 1),
        until: CalendarDate(2026, 4, 1),
        limit: '100',
      );
      final current = _budget(
        from: CalendarDate(2026, 4, 1),
        limit: '200',
      );
      final category = _category(budgets: [historical, current]);

      expect(category.budgetAt(CalendarDate(2025, 12, 31)), isNull);
      expect(category.budgetAt(CalendarDate(2026, 1, 1)), same(historical));
      expect(category.budgetAt(CalendarDate(2026, 3, 31)), same(historical));
      expect(category.budgetAt(CalendarDate(2026, 4, 1)), same(current));
    });

    test('compares equivalent categories by mapped values', () {
      final first = _category();
      final equivalent = _category();
      final different = _category(id: CategoryId.fromString('category-2'));

      expect(first, equivalent);
      expect(first.hashCode, equivalent.hashCode);
      expect(first, isNot(different));
    });
  });
}

Category _category({
  CategoryId? id,
  String name = 'Groceries',
  CategoryId? parentCategoryId,
  CategoryKind kind = CategoryKind.expense,
  List<CategoryBudget> budgets = const [],
  int sortOrder = 0,
  DateTime? createdAt,
  DateTime? modifiedAt,
  DateTime? deletedAt,
  int entityVersion = 1,
}) {
  final created = createdAt ?? DateTime.utc(2026, 9, 12);
  return Category(
    id: id ?? CategoryId.fromString('category-1'),
    name: name,
    parentCategoryId: parentCategoryId,
    kind: kind,
    budgets: budgets,
    icon: EntityIcon.storefront,
    color: EntityColor.green,
    sortOrder: sortOrder,
    deletedAt: deletedAt,
    createdAt: created,
    modifiedAt: modifiedAt ?? created,
    entityVersion: entityVersion,
  );
}

CategoryBudget _budget({
  required CalendarDate from,
  CalendarDate? until,
  String limit = '100',
}) {
  return CategoryBudget(
    limit: Decimal.parse(limit),
    period: BudgetPeriod.monthly,
    effectiveFrom: from,
    effectiveUntil: until,
  );
}
