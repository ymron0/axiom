@Tags(['application'])
library;

import 'package:axiom/src/features/rates/application/models/rate_source_observation.dart';
import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

void main() {
  group('RateSourceObservation', () {
    test('preserves a positive decimal rate exactly', () {
      // Given
      final value = Decimal.parse('1.087654321987654321');

      // When
      final observation = RateSourceObservation(
        rate: value,
        effectiveAt: DateTime.utc(2026, 9, 17),
      );

      // Then
      expect(observation.rate, value);
    });

    test('normalizes effective time to UTC', () {
      // Given
      final effectiveAt = DateTime.parse('2026-09-17T14:30:45.123+02:00');

      // When
      final observation = RateSourceObservation(
        rate: Decimal.parse('1.08'),
        effectiveAt: effectiveAt,
      );

      // Then
      expect(
        observation.effectiveAt,
        DateTime.utc(2026, 9, 17, 12, 30, 45, 123),
      );
      expect(observation.effectiveAt.isUtc, isTrue);
    });

    test('rejects zero rate', () {
      expect(
        () => RateSourceObservation(
          rate: Decimal.zero,
          effectiveAt: DateTime.utc(2026, 9, 17),
        ),
        throwsArgumentError,
      );
    });

    test('rejects negative rate', () {
      expect(
        () => RateSourceObservation(
          rate: Decimal.parse('-0.01'),
          effectiveAt: DateTime.utc(2026, 9, 17),
        ),
        throwsArgumentError,
      );
    });
  });
}
