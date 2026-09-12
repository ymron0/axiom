import 'package:axiom/src/core/ports/clock/clock_factory.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/core/ports/clock/system_clock.dart';
import 'package:test/test.dart';

void main() {
  group('createClock', () {
    test('selects the system clock when DEBUG_NOW is absent', () {
      expect(createClock(debugNow: ''), isA<SystemClock>());
    });

    test('selects a fixed clock for a valid DEBUG_NOW timestamp', () {
      const debugNow = '2026-01-01T08:05:00Z';

      final clock = createClock(debugNow: debugNow);

      expect(clock, isA<FixedClock>());
      expect(clock.now, DateTime.parse(debugNow));
      expect(clock.nowUtc, DateTime.parse(debugNow).toUtc());
      expect(clock.now, clock.now);
    });

    test('throws FormatException for an invalid DEBUG_NOW value', () {
      expect(
        () => createClock(debugNow: 'invalid'),
        throwsFormatException,
      );
    });
  });
}
