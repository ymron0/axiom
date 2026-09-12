import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/features/rates/domain/services/rate_conversion_service.dart';
import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/rates/rate_fixtures.dart';

void main() {
  group('RateConversionService', () {
    const service = RateConversionService();
    final eur = AssetId.fromString('EUR');
    final chf = AssetId.fromString('CHF');
    final usd = AssetId.fromString('USD');

    test('inverts a rate using exact decimal arithmetic', () {
      // Given
      final rate = exchangeRateFixture(rate: '0.8');

      // When
      final result = service.invert(rate);

      // Then
      expect(result, Decimal.parse('1.25'));
    });

    test('preserves configured precision for a repeating inverse', () {
      // Given
      final rate = exchangeRateFixture(rate: '3');

      // When
      final result = service.invert(rate);

      // Then
      expect(result, Decimal.parse('0.333333333333333333'));
    });

    test('calculates a cross rate through the bridge asset', () {
      // Given
      final eurUsd = exchangeRateFixture(
        baseAssetId: 'EUR',
        quoteAssetId: 'USD',
        rate: '1.18',
      );
      final chfUsd = exchangeRateFixture(
        baseAssetId: 'CHF',
        quoteAssetId: 'USD',
        rate: '1.26',
      );

      // When
      final result = service.cross(
        baseBridgeRate: eurUsd,
        quoteBridgeRate: chfUsd,
        bridgeAssetId: usd,
      );

      // Then
      expect(result, Decimal.parse('0.936507936507936507'));
    });

    test('returns one when cross-rate base assets are equal', () {
      final first = exchangeRateFixture(
        baseAssetId: 'EUR',
        quoteAssetId: 'USD',
        rate: '1.18',
      );
      final second = exchangeRateFixture(
        baseAssetId: 'EUR',
        quoteAssetId: 'USD',
        rate: '1.26',
      );

      expect(
        service.cross(
          baseBridgeRate: first,
          quoteBridgeRate: second,
          bridgeAssetId: usd,
        ),
        Decimal.one,
      );
    });

    test('resolves the same asset to one without rates', () {
      expect(
        service.resolve(
          baseAssetId: eur,
          quoteAssetId: eur,
          bridgeAssetId: usd,
        ),
        Decimal.one,
      );
    });

    test('resolves a base asset directly against the bridge', () {
      final rate = exchangeRateFixture(
        baseAssetId: 'EUR',
        quoteAssetId: 'USD',
        rate: '1.18',
      );

      expect(
        service.resolve(
          baseAssetId: eur,
          quoteAssetId: usd,
          bridgeAssetId: usd,
          baseBridgeRate: rate,
        ),
        Decimal.parse('1.18'),
      );
    });

    test('resolves a bridge asset against the quote by inversion', () {
      final rate = exchangeRateFixture(
        baseAssetId: 'CHF',
        quoteAssetId: 'USD',
        rate: '0.8',
      );

      expect(
        service.resolve(
          baseAssetId: usd,
          quoteAssetId: chf,
          bridgeAssetId: usd,
          quoteBridgeRate: rate,
        ),
        Decimal.parse('1.25'),
      );
    });

    test('resolves two non-bridge assets through the bridge', () {
      final eurUsd = exchangeRateFixture(
        baseAssetId: 'EUR',
        quoteAssetId: 'USD',
        rate: '1.18',
      );
      final chfUsd = exchangeRateFixture(
        baseAssetId: 'CHF',
        quoteAssetId: 'USD',
        rate: '1.26',
      );

      expect(
        service.resolve(
          baseAssetId: eur,
          quoteAssetId: chf,
          bridgeAssetId: usd,
          baseBridgeRate: eurUsd,
          quoteBridgeRate: chfUsd,
        ),
        Decimal.parse('0.936507936507936507'),
      );
    });

    test('rejects a bridge rate quoted in the wrong asset', () {
      final wrongRate = exchangeRateFixture(
        baseAssetId: 'EUR',
        quoteAssetId: 'CHF',
      );

      expect(
        () => service.cross(
          baseBridgeRate: wrongRate,
          quoteBridgeRate: exchangeRateFixture(baseAssetId: 'CHF'),
          bridgeAssetId: usd,
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('requires the base bridge rate for a direct resolution', () {
      expect(
        () => service.resolve(
          baseAssetId: eur,
          quoteAssetId: usd,
          bridgeAssetId: usd,
        ),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.name,
            'name',
            'baseBridgeRate',
          ),
        ),
      );
    });

    test('requires the quote bridge rate for an inverse resolution', () {
      expect(
        () => service.resolve(
          baseAssetId: usd,
          quoteAssetId: chf,
          bridgeAssetId: usd,
        ),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.name,
            'name',
            'quoteBridgeRate',
          ),
        ),
      );
    });

    test('requires the base bridge rate for a cross resolution', () {
      expect(
        () => service.resolve(
          baseAssetId: eur,
          quoteAssetId: chf,
          bridgeAssetId: usd,
          quoteBridgeRate: exchangeRateFixture(baseAssetId: 'CHF'),
        ),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.name,
            'name',
            'baseBridgeRate',
          ),
        ),
      );
    });

    test('requires the quote bridge rate for a cross resolution', () {
      expect(
        () => service.resolve(
          baseAssetId: eur,
          quoteAssetId: chf,
          bridgeAssetId: usd,
          baseBridgeRate: exchangeRateFixture(baseAssetId: 'EUR'),
        ),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.name,
            'name',
            'quoteBridgeRate',
          ),
        ),
      );
    });

    test('rejects a rate with an unexpected ordered pair', () {
      expect(
        () => service.resolve(
          baseAssetId: eur,
          quoteAssetId: usd,
          bridgeAssetId: usd,
          baseBridgeRate: exchangeRateFixture(
            baseAssetId: 'CHF',
            quoteAssetId: 'USD',
          ),
        ),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
