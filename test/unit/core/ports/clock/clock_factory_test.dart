import 'package:axiom/src/core/ports/clock/clock_factory.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/core/ports/clock/system_clock.dart';
import 'package:test/test.dart';

void main() {
  group('createClock', () {
    const debugNow = String.fromEnvironment('DEBUG_NOW');

    test('selects the system clock when DEBUG_NOW is absent', () {
      if (debugNow.isNotEmpty) {
        return;
      }

      expect(createClock(), isA<SystemClock>());
    });

    test('selects a fixed clock for a valid DEBUG_NOW timestamp', () {
      if (debugNow.isEmpty || debugNow == 'invalid') {
        return;
      }

      final clock = createClock();

      expect(clock, isA<FixedClock>());
      expect(clock.now, DateTime.parse(debugNow));
      expect(clock.nowUtc, DateTime.parse(debugNow).toUtc());
      expect(clock.now, clock.now);
    });

    test('throws FormatException for an invalid DEBUG_NOW value', () {
      if (debugNow != 'invalid') {
        return;
      }

      expect(createClock, throwsFormatException);
    });
  });
}
