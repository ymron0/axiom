@Tags(['domain'])
library;

import 'package:axiom/src/core/domain/value_objects/calendar_date.dart';
import 'package:axiom/src/features/transactions/domain/enums/recurrence_frequency.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/recurrence_end.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/recurrence_rule.dart';
import 'package:test/test.dart';

void main() {
  group('RecurrenceRule', () {
    test('rejects an interval below one', () {
      expect(
        () => RecurrenceRule(
          startsOn: CalendarDate(2026, 1, 1),
          frequency: RecurrenceFrequency.daily,
          interval: 0,
        ),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.name,
            'name',
            'interval',
          ),
        ),
      );
    });

    test('rejects an end date before the start date', () {
      expect(
        () => RecurrenceRule(
          startsOn: CalendarDate(2026, 1, 2),
          frequency: RecurrenceFrequency.daily,
          end: RecurrenceEnd(until: CalendarDate(2026, 1, 1)),
        ),
        throwsA(
          isA<ArgumentError>().having((error) => error.name, 'name', 'end'),
        ),
      );
    });

    test('accepts an end date equal to the start date', () {
      final rule = RecurrenceRule(
        startsOn: CalendarDate(2026, 1, 1),
        frequency: RecurrenceFrequency.daily,
        end: RecurrenceEnd(until: CalendarDate(2026, 1, 1)),
      );

      expect(rule.occurrenceAt(0)?.toString(), '2026-01-01');
      expect(rule.occurrenceAt(1), isNull);
    });

    test('rejects a negative occurrence index', () {
      final rule = _daily();

      expect(
        () => rule.occurrenceAt(-1),
        throwsA(
          isA<RangeError>().having((error) => error.name, 'name', 'index'),
        ),
      );
    });

    test('rejects negative additional occurrences', () {
      final rule = _daily();

      expect(
        () => rule.occurrenceAt(0, additionalOccurrences: -1),
        throwsA(
          isA<RangeError>().having(
            (error) => error.name,
            'name',
            'additionalOccurrences',
          ),
        ),
      );
    });

    test('calculates daily recurrence using the configured interval', () {
      final rule = RecurrenceRule(
        startsOn: CalendarDate(2026, 1, 1),
        frequency: RecurrenceFrequency.daily,
        interval: 2,
      );

      expect(rule.occurrenceAt(0)?.toString(), '2026-01-01');
      expect(rule.occurrenceAt(1)?.toString(), '2026-01-03');
      expect(rule.occurrenceAt(2)?.toString(), '2026-01-05');

      expect(rule.occursOn(CalendarDate(2026, 1, 3)), isTrue);
      expect(rule.occursOn(CalendarDate(2026, 1, 4)), isFalse);
    });

    test('calculates weekly recurrence as seven-day calendar intervals', () {
      final rule = RecurrenceRule(
        startsOn: CalendarDate(2026, 1, 5),
        frequency: RecurrenceFrequency.weekly,
        interval: 2,
      );

      expect(rule.occurrenceAt(0)?.toString(), '2026-01-05');
      expect(rule.occurrenceAt(1)?.toString(), '2026-01-19');
      expect(rule.occurrenceAt(2)?.toString(), '2026-02-02');

      expect(
        rule.nextOnOrAfter(CalendarDate(2026, 1, 6))?.toString(),
        '2026-01-19',
      );
      expect(
        rule.nextOnOrAfter(CalendarDate(2026, 1, 19))?.toString(),
        '2026-01-19',
      );
    });

    test('monthly recurrence remains anchored to the original day', () {
      final rule = RecurrenceRule(
        startsOn: CalendarDate(2026, 1, 31),
        frequency: RecurrenceFrequency.monthly,
      );

      expect(rule.occurrenceAt(0)?.toString(), '2026-01-31');
      expect(rule.occurrenceAt(1)?.toString(), '2026-02-28');
      expect(rule.occurrenceAt(2)?.toString(), '2026-03-31');
      expect(rule.occurrenceAt(3)?.toString(), '2026-04-30');
      expect(rule.occurrenceAt(4)?.toString(), '2026-05-31');
    });

    test('monthly next occurrence handles clamped target dates', () {
      final rule = RecurrenceRule(
        startsOn: CalendarDate(2026, 1, 31),
        frequency: RecurrenceFrequency.monthly,
      );

      expect(
        rule.nextOnOrAfter(CalendarDate(2026, 2, 1))?.toString(),
        '2026-02-28',
      );

      expect(
        rule.nextOnOrAfter(CalendarDate(2026, 2, 28))?.toString(),
        '2026-02-28',
      );

      expect(
        rule.nextOnOrAfter(CalendarDate(2026, 3, 1))?.toString(),
        '2026-03-31',
      );
    });

    test('monthly recurrence supports intervals greater than one', () {
      final rule = RecurrenceRule(
        startsOn: CalendarDate(2026, 1, 31),
        frequency: RecurrenceFrequency.monthly,
        interval: 2,
      );

      expect(rule.occurrenceAt(0)?.toString(), '2026-01-31');
      expect(rule.occurrenceAt(1)?.toString(), '2026-03-31');
      expect(rule.occurrenceAt(2)?.toString(), '2026-05-31');

      expect(
        rule.nextOnOrAfter(CalendarDate(2026, 2, 1))?.toString(),
        '2026-03-31',
      );
    });

    test('yearly leap-day recurrence clamps without losing its anchor', () {
      final rule = RecurrenceRule(
        startsOn: CalendarDate(2024, 2, 29),
        frequency: RecurrenceFrequency.yearly,
      );

      expect(rule.occurrenceAt(0)?.toString(), '2024-02-29');
      expect(rule.occurrenceAt(1)?.toString(), '2025-02-28');
      expect(rule.occurrenceAt(2)?.toString(), '2026-02-28');
      expect(rule.occurrenceAt(3)?.toString(), '2027-02-28');
      expect(rule.occurrenceAt(4)?.toString(), '2028-02-29');
    });

    test('yearly recurrence supports intervals greater than one', () {
      final rule = RecurrenceRule(
        startsOn: CalendarDate(2024, 6, 15),
        frequency: RecurrenceFrequency.yearly,
        interval: 2,
      );

      expect(rule.occurrenceAt(0)?.toString(), '2024-06-15');
      expect(rule.occurrenceAt(1)?.toString(), '2026-06-15');
      expect(rule.occurrenceAt(2)?.toString(), '2028-06-15');

      expect(
        rule.nextOnOrAfter(CalendarDate(2025, 1, 1))?.toString(),
        '2026-06-15',
      );
    });

    test('dates before the start are not occurrences', () {
      final rule = _daily();

      expect(rule.occursOn(CalendarDate(2025, 12, 31)), isFalse);

      expect(
        rule.nextOnOrAfter(CalendarDate(2025, 12, 31))?.toString(),
        '2026-01-01',
      );
    });

    test(
      'count terminates the recurrence after the configured occurrences',
      () {
        final rule = RecurrenceRule(
          startsOn: CalendarDate(2026, 1, 1),
          frequency: RecurrenceFrequency.daily,
          end: RecurrenceEnd(count: 3),
        );

        expect(rule.occurrenceAt(0)?.toString(), '2026-01-01');
        expect(rule.occurrenceAt(1)?.toString(), '2026-01-02');
        expect(rule.occurrenceAt(2)?.toString(), '2026-01-03');
        expect(rule.occurrenceAt(3), isNull);

        expect(rule.nextOnOrAfter(CalendarDate(2026, 1, 4)), isNull);
      },
    );

    test('inclusive until date terminates later occurrences', () {
      final rule = RecurrenceRule(
        startsOn: CalendarDate(2026, 1, 1),
        frequency: RecurrenceFrequency.daily,
        end: RecurrenceEnd(until: CalendarDate(2026, 1, 3)),
      );

      expect(rule.occurrenceAt(2)?.toString(), '2026-01-03');
      expect(rule.occurrenceAt(3), isNull);
    });

    test(
      'until date between occurrences terminates recurrence after the prior occurrence',
      () {
        final rule = RecurrenceRule(
          startsOn: CalendarDate(2026, 1, 1),
          frequency: RecurrenceFrequency.daily,
          interval: 2,
          end: RecurrenceEnd(until: CalendarDate(2026, 1, 4)),
        );

        expect(rule.occurrenceAt(1)?.toString(), '2026-01-03');
        expect(rule.occurrenceAt(2), isNull);
      },
    );

    test('both termination conditions stop at whichever is reached first', () {
      final rule = RecurrenceRule(
        startsOn: CalendarDate(2026, 1, 1),
        frequency: RecurrenceFrequency.daily,
        end: RecurrenceEnd(until: CalendarDate(2026, 12, 31), count: 2),
      );

      expect(rule.occurrenceAt(0), isNotNull);
      expect(rule.occurrenceAt(1), isNotNull);
      expect(rule.occurrenceAt(2), isNull);
    });

    test('returns immutable occurrences inside a half-open range', () {
      final rule = RecurrenceRule(
        startsOn: CalendarDate(2026, 1, 1),
        frequency: RecurrenceFrequency.daily,
        interval: 2,
      );

      final occurrences = rule.occurrencesBetween(
        from: CalendarDate(2026, 1, 2),
        until: CalendarDate(2026, 1, 8),
      );

      expect(occurrences.map((date) => date.toString()).toList(), [
        '2026-01-03',
        '2026-01-05',
        '2026-01-07',
      ]);

      expect(
        () => occurrences.add(CalendarDate(2026, 1, 9)),
        throwsUnsupportedError,
      );
    });

    test('stops range enumeration when the recurrence terminates', () {
      final rule = RecurrenceRule(
        startsOn: CalendarDate(2026, 1, 1),
        frequency: RecurrenceFrequency.daily,
        end: RecurrenceEnd(count: 2),
      );

      final occurrences = rule.occurrencesBetween(
        from: CalendarDate(2026, 1, 1),
        until: CalendarDate(2027, 1, 1),
      );

      expect(occurrences.map((date) => date.toString()).toList(), [
        '2026-01-01',
        '2026-01-02',
      ]);
    });

    test('rejects an empty occurrence range', () {
      final rule = _daily();

      expect(
        () => rule.occurrencesBetween(
          from: CalendarDate(2026, 2, 1),
          until: CalendarDate(2026, 2, 1),
        ),
        throwsA(
          isA<ArgumentError>().having((error) => error.name, 'name', 'until'),
        ),
      );
    });

    test('rejects a backwards occurrence range', () {
      final rule = _daily();

      expect(
        () => rule.occurrencesBetween(
          from: CalendarDate(2026, 2, 2),
          until: CalendarDate(2026, 2, 1),
        ),
        throwsA(
          isA<ArgumentError>().having((error) => error.name, 'name', 'until'),
        ),
      );
    });
  });
}

RecurrenceRule _daily() {
  return RecurrenceRule(
    startsOn: CalendarDate(2026, 1, 1),
    frequency: RecurrenceFrequency.daily,
  );
}
