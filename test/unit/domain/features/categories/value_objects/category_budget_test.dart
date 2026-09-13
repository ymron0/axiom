import 'package:axiom/src/core/domain/value_objects/calendar_date.dart';
import 'package:axiom/src/features/categories/domain/enums/budget_period.dart';
import 'package:axiom/src/features/categories/domain/value_objects/category_budget.dart';
import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

void main() {
  group('CategoryBudget', () {
    test('accepts zero and positive limits', () {
      final zero = _budget(limit: Decimal.zero);
      final positive = _budget(limit: Decimal.parse('125.50'));

      expect(zero.limit, Decimal.zero);
      expect(positive.limit, Decimal.parse('125.50'));
    });

    test('rejects negative limits', () {
      expect(
        () => _budget(limit: Decimal.parse('-0.01')),
        throwsA(isA<ArgumentError>().having((e) => e.name, 'name', 'limit')),
      );
    });

    test('rejects an end date equal to or before the start date', () {
      final start = CalendarDate(2026, 1, 1);
      expect(
        () => _budget(effectiveUntil: start),
        throwsA(isA<ArgumentError>().having((e) => e.name, 'name', 'effectiveUntil')),
      );
      expect(
        () => _budget(effectiveUntil: CalendarDate(2025, 12, 31)),
        throwsA(isA<ArgumentError>().having((e) => e.name, 'name', 'effectiveUntil')),
      );
    });

    test('applies from the inclusive start to the exclusive end', () {
      final budget = _budget(
        effectiveUntil: CalendarDate(2026, 4, 1),
      );

      expect(budget.appliesOn(CalendarDate(2025, 12, 31)), isFalse);
      expect(budget.appliesOn(CalendarDate(2026, 1, 1)), isTrue);
      expect(budget.appliesOn(CalendarDate(2026, 3, 31)), isTrue);
      expect(budget.appliesOn(CalendarDate(2026, 4, 1)), isFalse);
    });

    test('with no end date remains effective indefinitely', () {
      final budget = _budget();

      expect(budget.appliesOn(CalendarDate(2099, 12, 31)), isTrue);
    });
  });
}

CategoryBudget _budget({
  Decimal? limit,
  CalendarDate? effectiveUntil,
}) {
  return CategoryBudget(
    limit: limit ?? Decimal.parse('100'),
    period: BudgetPeriod.monthly,
    effectiveFrom: CalendarDate(2026, 1, 1),
    effectiveUntil: effectiveUntil,
  );
}
