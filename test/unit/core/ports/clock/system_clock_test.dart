import 'package:axiom/src/core/ports/clock/system_clock.dart';
import 'package:test/test.dart';

void main() {
  group('SystemClock', () {
    test('now uses system time when debugNow is empty', () {
      const clock = SystemClock();

      final before = DateTime.now();
      final actual = clock.now;
      final after = DateTime.now();

      expect(actual.isBefore(before), isFalse);
      expect(actual.isAfter(after), isFalse);
    });

    test('now uses debugNow when configured', () {
      const debugNow = '2026-09-06T12:34:56Z';
      const clock = SystemClock(debugNow: debugNow);

      expect(clock.now, DateTime.parse(debugNow));
    });

    test('nowUtc converts debugNow to UTC', () {
      const debugNow = '2026-09-06T12:34:56+02:00';
      const clock = SystemClock(debugNow: debugNow);

      final actual = clock.nowUtc;

      expect(actual, DateTime.parse(debugNow).toUtc());
      expect(actual.isUtc, isTrue);
    });

    test('now throws FormatException when debugNow is invalid', () {
      const clock = SystemClock(debugNow: 'not-a-date');

      expect(() => clock.now, throwsFormatException);
    });

    test('nowUtc throws FormatException when debugNow is invalid', () {
      const clock = SystemClock(debugNow: 'not-a-date');

      expect(() => clock.nowUtc, throwsFormatException);
    });
  });
}
