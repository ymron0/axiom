import 'package:axiom/src/core/domain/value_objects/calendar_date.dart';
import 'package:test/test.dart';

void main() {
  group('CalendarDate', () {
    test('accepts valid dates including leap day', () {
      final date = CalendarDate(2028, 2, 29);

      expect(date.year, 2028);
      expect(date.month, 2);
      expect(date.day, 29);
      expect(date.toDateTimeUtc(), DateTime.utc(2028, 2, 29));
      expect(date.toString(), '2028-02-29');
    });

    test('rejects invalid month and day combinations', () {
      expect(() => CalendarDate(2026, 0, 1), throwsA(isA<ArgumentError>()));
      expect(() => CalendarDate(2026, 13, 1), throwsA(isA<ArgumentError>()));
      expect(() => CalendarDate(2026, 2, 29), throwsA(isA<ArgumentError>()));
      expect(() => CalendarDate(2026, 4, 31), throwsA(isA<ArgumentError>()));
    });

    test('creates a date from a DateTime while discarding its time', () {
      final date = CalendarDate.fromDateTime(
        DateTime.parse('2026-09-12T23:45:10+02:00'),
      );

      expect(date, CalendarDate(2026, 9, 12));
      expect(date.toDateTimeUtc(), DateTime.utc(2026, 9, 12));
    });

    test('compares dates chronologically and exposes boundary predicates', () {
      final earlier = CalendarDate(2026, 1, 1);
      final same = CalendarDate(2026, 1, 1);
      final later = CalendarDate(2026, 1, 2);

      expect(earlier.compareTo(same), 0);
      expect(earlier.compareTo(later), lessThan(0));
      expect(later.compareTo(earlier), greaterThan(0));
      expect(earlier.isBefore(later), isTrue);
      expect(earlier.isAfter(later), isFalse);
      expect(earlier.isOnOrBefore(same), isTrue);
      expect(later.isOnOrBefore(earlier), isFalse);
      expect(later.isOnOrAfter(same), isTrue);
      expect(earlier.isOnOrAfter(later), isFalse);
    });

    test('formats single-digit month and day with padding', () {
      expect(CalendarDate(2026, 1, 2).toString(), '2026-01-02');
    });

    test('compares and maps equal values consistently', () {
      final first = CalendarDate(2026, 9, 12);
      final equivalent = CalendarDate(2026, 9, 12);
      final different = CalendarDate(2026, 9, 13);

      expect(first, equivalent);
      expect(first.hashCode, equivalent.hashCode);
      expect(first, isNot(different));
    });
  });
}
