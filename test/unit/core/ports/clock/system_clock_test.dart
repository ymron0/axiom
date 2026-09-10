import 'package:axiom/src/core/ports/clock/system_clock.dart';
import 'package:test/test.dart';

void main() {
  group('SystemClock', () {
    test('now uses system time', () {
      const clock = SystemClock();

      final before = DateTime.now();
      final actual = clock.now;
      final after = DateTime.now();

      expect(actual.isBefore(before), isFalse);
      expect(actual.isAfter(after), isFalse);
    });

    test('nowUtc uses current system time in UTC', () {
      const clock = SystemClock();

      final before = DateTime.now().toUtc();
      final actual = clock.nowUtc;
      final after = DateTime.now().toUtc();

      expect(actual.isUtc, isTrue);
      expect(actual.isBefore(before), isFalse);
      expect(actual.isAfter(after), isFalse);
    });
  });
}
