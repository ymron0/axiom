@Tags(['data'])
library;

import 'package:axiom/src/features/assets/domain/value_objects/asset_code.dart';
import 'package:axiom/src/features/rates/data/models/market_price_observation.dart';
import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

void main() {
  group('MarketPriceObservation', () {
    test('stores an exact ordered market-price pair', () {
      // Given
      final btc = AssetCode('BTC');
      final usd = AssetCode('USD');
      final price = Decimal.parse('65432.123456789');
      final effectiveAt = DateTime.utc(2026, 9, 17, 10, 30);

      // When
      final observation = MarketPriceObservation(
        baseAssetCode: btc,
        quoteAssetCode: usd,
        price: price,
        effectiveAt: effectiveAt,
      );

      // Then
      expect(observation.baseAssetCode, btc);
      expect(observation.quoteAssetCode, usd);
      expect(observation.price, price);
      expect(observation.effectiveAt, effectiveAt);
    });

    test('does not round the supplied decimal price', () {
      // Given
      final price = Decimal.parse('0.123456789123456789');

      // When
      final observation = MarketPriceObservation(
        baseAssetCode: AssetCode('TOKEN'),
        quoteAssetCode: AssetCode('USD'),
        price: price,
        effectiveAt: DateTime.utc(2026, 9, 17),
      );

      // Then
      expect(observation.price, Decimal.parse('0.123456789123456789'));
    });

    test('normalizes effectiveAt to UTC', () {
      // Given
      final effectiveAt = DateTime.parse('2026-09-17T12:30:00+02:00');

      // When
      final observation = MarketPriceObservation(
        baseAssetCode: AssetCode('BTC'),
        quoteAssetCode: AssetCode('USD'),
        price: Decimal.parse('65000'),
        effectiveAt: effectiveAt,
      );

      // Then
      expect(observation.effectiveAt.isUtc, isTrue);
      expect(observation.effectiveAt, DateTime.parse('2026-09-17T10:30:00Z'));
    });

    test('rejects identical base and quote asset codes', () {
      // Given
      final btc = AssetCode('BTC');

      // When / Then
      expect(
        () => MarketPriceObservation(
          baseAssetCode: btc,
          quoteAssetCode: btc,
          price: Decimal.parse('1'),
          effectiveAt: DateTime.utc(2026, 9, 17),
        ),
        throwsA(
          isA<ArgumentError>()
              .having((error) => error.name, 'name', 'quoteAssetCode')
              .having((error) => error.invalidValue, 'invalidValue', btc),
        ),
      );
    });

    test('rejects a zero price', () {
      // When / Then
      expect(
        () => MarketPriceObservation(
          baseAssetCode: AssetCode('BTC'),
          quoteAssetCode: AssetCode('USD'),
          price: Decimal.zero,
          effectiveAt: DateTime.utc(2026, 9, 17),
        ),
        throwsA(
          isA<ArgumentError>()
              .having((error) => error.name, 'name', 'price')
              .having(
                (error) => error.invalidValue,
                'invalidValue',
                Decimal.zero,
              ),
        ),
      );
    });

    test('rejects a negative price', () {
      // Given
      final price = Decimal.parse('-1.25');

      // When / Then
      expect(
        () => MarketPriceObservation(
          baseAssetCode: AssetCode('BTC'),
          quoteAssetCode: AssetCode('USD'),
          price: price,
          effectiveAt: DateTime.utc(2026, 9, 17),
        ),
        throwsA(
          isA<ArgumentError>()
              .having((error) => error.name, 'name', 'price')
              .having((error) => error.invalidValue, 'invalidValue', price),
        ),
      );
    });
  });
}
