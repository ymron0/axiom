@Tags(['domain'])
library;

import 'package:axiom/src/core/domain/value_objects/calendar_date.dart';
import 'package:axiom/src/features/balance_snapshots/domain/value_objects/balance_snapshot_date_range.dart';
import 'package:test/test.dart';

void main() {
  group('BalanceSnapshotDateRange', () {
    test('accepts an ordered date range', () {
      final range = BalanceSnapshotDateRange(
        from: CalendarDate(2026, 7, 1),
        until: CalendarDate(2026, 8, 1),
      );

      expect(range.from, CalendarDate(2026, 7, 1));
      expect(range.until, CalendarDate(2026, 8, 1));
      expect(range.isEmpty, isFalse);
    });

    test('allows equal bounds as an empty range', () {
      final date = CalendarDate(2026, 7, 1);

      final range = BalanceSnapshotDateRange(from: date, until: date);

      expect(range.isEmpty, isTrue);
    });

    test('rejects an end date before the start date', () {
      expect(
        () => BalanceSnapshotDateRange(
          from: CalendarDate(2026, 8, 1),
          until: CalendarDate(2026, 7, 31),
        ),
        throwsA(
          isA<ArgumentError>()
              .having((error) => error.name, 'name', 'until')
              .having(
                (error) => error.invalidValue,
                'invalidValue',
                CalendarDate(2026, 7, 31),
              ),
        ),
      );
    });

    test('contains the inclusive lower bound', () {
      final range = BalanceSnapshotDateRange(
        from: CalendarDate(2026, 7, 1),
        until: CalendarDate(2026, 8, 1),
      );

      expect(range.contains(CalendarDate(2026, 7, 1)), isTrue);
    });

    test('contains a date inside the range', () {
      final range = BalanceSnapshotDateRange(
        from: CalendarDate(2026, 7, 1),
        until: CalendarDate(2026, 8, 1),
      );

      expect(range.contains(CalendarDate(2026, 7, 15)), isTrue);
    });

    test('excludes the exclusive upper bound', () {
      final range = BalanceSnapshotDateRange(
        from: CalendarDate(2026, 7, 1),
        until: CalendarDate(2026, 8, 1),
      );

      expect(range.contains(CalendarDate(2026, 8, 1)), isFalse);
    });

    test('excludes a date before the range', () {
      final range = BalanceSnapshotDateRange(
        from: CalendarDate(2026, 7, 1),
        until: CalendarDate(2026, 8, 1),
      );

      expect(range.contains(CalendarDate(2026, 6, 30)), isFalse);
    });

    test('excludes a date after the range', () {
      final range = BalanceSnapshotDateRange(
        from: CalendarDate(2026, 7, 1),
        until: CalendarDate(2026, 8, 1),
      );

      expect(range.contains(CalendarDate(2026, 8, 2)), isFalse);
    });

    test('empty range contains no date', () {
      final range = BalanceSnapshotDateRange(
        from: CalendarDate(2026, 7, 1),
        until: CalendarDate(2026, 7, 1),
      );

      expect(range.contains(CalendarDate(2026, 6, 30)), isFalse);

      expect(range.contains(CalendarDate(2026, 7, 1)), isFalse);

      expect(range.contains(CalendarDate(2026, 7, 2)), isFalse);
    });
  });
}
