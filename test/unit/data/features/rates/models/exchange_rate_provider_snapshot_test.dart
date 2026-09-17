import 'package:axiom/src/features/rates/data/models/exchange_rate_provider_snapshot.dart';
import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

void main() {
  group('ExchangeRateProviderSnapshot', () {
    test('stores provider data', () {
      // Given
      final rates = <String, Decimal>{
        'EUR': Decimal.parse('0.85'),
        'CHF': Decimal.parse('0.79'),
      };
      final effectiveAt = DateTime.utc(2026, 9, 17, 8);

      // When
      final snapshot = ExchangeRateProviderSnapshot(
        baseCurrencyCode: 'USD',
        quoteUnitsPerBaseUnit: rates,
        effectiveAt: effectiveAt,
      );

      // Then
      expect(snapshot.baseCurrencyCode, 'USD');
      expect(snapshot.quoteUnitsPerBaseUnit, {
        'EUR': Decimal.parse('0.85'),
        'CHF': Decimal.parse('0.79'),
      });
      expect(snapshot.effectiveAt, effectiveAt);
    });

    test('normalizes effective time to UTC', () {
      // Given
      final effectiveAt = DateTime.parse('2026-09-17T14:30:00+02:00');

      // When
      final snapshot = ExchangeRateProviderSnapshot(
        baseCurrencyCode: 'USD',
        quoteUnitsPerBaseUnit: {'EUR': Decimal.parse('0.85')},
        effectiveAt: effectiveAt,
      );

      // Then
      expect(snapshot.effectiveAt, DateTime.utc(2026, 9, 17, 12, 30));
      expect(snapshot.effectiveAt.isUtc, isTrue);
    });

    test('creates an immutable copy of provider rates', () {
      // Given
      final source = <String, Decimal>{'EUR': Decimal.parse('0.85')};

      final snapshot = ExchangeRateProviderSnapshot(
        baseCurrencyCode: 'USD',
        quoteUnitsPerBaseUnit: source,
        effectiveAt: DateTime.utc(2026, 9, 17),
      );

      // When
      source['EUR'] = Decimal.parse('999');

      // Then
      expect(snapshot.quoteUnitsPerBaseUnit['EUR'], Decimal.parse('0.85'));
    });

    test('does not allow returned provider rates to be modified', () {
      // Given
      final snapshot = ExchangeRateProviderSnapshot(
        baseCurrencyCode: 'USD',
        quoteUnitsPerBaseUnit: {'EUR': Decimal.parse('0.85')},
        effectiveAt: DateTime.utc(2026, 9, 17),
      );

      // When
      void operation() {
        snapshot.quoteUnitsPerBaseUnit['EUR'] = Decimal.one;
      }

      // Then
      expect(operation, throwsUnsupportedError);
    });
  });
}
