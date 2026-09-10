import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:test/test.dart';

void main() {
  group('FixedClock', () {
    test('returns the supplied instant from repeated now reads', () {
      final instant = DateTime(2026, 9, 10, 12, 34, 56);
      final clock = FixedClock(instant);

      final first = clock.now;
      final second = clock.now;

      expect(first, instant);
      expect(second, instant);
      expect(second, first);
    });

    test(
      'returns the corresponding UTC instant from repeated nowUtc reads',
      () {
        final instant = DateTime.parse('2026-09-10T12:34:56+02:00');
        final clock = FixedClock(instant);

        final first = clock.nowUtc;
        final second = clock.nowUtc;

        expect(first, instant.toUtc());
        expect(second, first);
        expect(first.isUtc, isTrue);
      },
    );

    test('preserves the supplied local representation in now', () {
      final instant = DateTime.parse('2026-09-10T12:34:56+02:00');
      final clock = FixedClock(instant);

      expect(clock.now, instant);
    });
  });
}
