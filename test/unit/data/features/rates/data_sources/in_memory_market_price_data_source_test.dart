@Tags(['data'])
library;

import 'package:axiom/src/features/assets/domain/value_objects/asset_code.dart';
import 'package:axiom/src/features/rates/data/failures/market_price_not_found_failure.dart';
import 'package:axiom/src/features/rates/data/models/market_price_observation.dart';
import 'package:axiom/src/features/rates/data/data_sources/in_memory_market_price_data_source.dart';
import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

void main() {
  group('InMemoryMarketPriceDataSource', () {
    test('returns the latest observation for the exact ordered pair', () async {
      // Given
      final older = _observation(
        price: '64000',
        effectiveAt: DateTime.utc(2026, 9, 16),
      );
      final latest = _observation(
        price: '65000',
        effectiveAt: DateTime.utc(2026, 9, 17),
      );

      final source = InMemoryMarketPriceDataSource(
        observations: [older, latest],
      );

      // When
      final result = await source.getLatest(
        baseAssetCode: AssetCode('BTC'),
        quoteAssetCode: AssetCode('USD'),
      );

      // Then
      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, same(latest));
      expect(result.failureOrNull, isNull);
    });

    test('selection does not depend on observation order', () async {
      // Given
      final older = _observation(
        price: '64000',
        effectiveAt: DateTime.utc(2026, 9, 16),
      );
      final latest = _observation(
        price: '65000',
        effectiveAt: DateTime.utc(2026, 9, 17),
      );

      final source = InMemoryMarketPriceDataSource(
        observations: [latest, older],
      );

      // When
      final result = await source.getLatest(
        baseAssetCode: AssetCode('BTC'),
        quoteAssetCode: AssetCode('USD'),
      );

      // Then
      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, same(latest));
    });

    test('keeps different quote assets separate', () async {
      // Given
      final btcUsd = _observation(quoteAssetCode: 'USD', price: '65000');
      final btcChf = _observation(quoteAssetCode: 'CHF', price: '51000');

      final source = InMemoryMarketPriceDataSource(
        observations: [btcUsd, btcChf],
      );

      // When
      final usdResult = await source.getLatest(
        baseAssetCode: AssetCode('BTC'),
        quoteAssetCode: AssetCode('USD'),
      );
      final chfResult = await source.getLatest(
        baseAssetCode: AssetCode('BTC'),
        quoteAssetCode: AssetCode('CHF'),
      );

      // Then
      expect(usdResult.valueOrNull, same(btcUsd));
      expect(chfResult.valueOrNull, same(btcChf));
    });

    test('does not invert an available reverse pair', () async {
      // Given
      final btcUsd = _observation(
        baseAssetCode: 'BTC',
        quoteAssetCode: 'USD',
        price: '65000',
      );

      final source = InMemoryMarketPriceDataSource(observations: [btcUsd]);

      // When
      final result = await source.getLatest(
        baseAssetCode: AssetCode('USD'),
        quoteAssetCode: AssetCode('BTC'),
      );

      // Then
      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, isA<MarketPriceNotFoundFailure>());
    });

    test('does not derive a cross-price through another asset', () async {
      // Given
      final btcUsd = _observation(
        baseAssetCode: 'BTC',
        quoteAssetCode: 'USD',
        price: '65000',
      );
      final chfUsd = _observation(
        baseAssetCode: 'CHF',
        quoteAssetCode: 'USD',
        price: '1.25',
      );

      final source = InMemoryMarketPriceDataSource(
        observations: [btcUsd, chfUsd],
      );

      // When
      final result = await source.getLatest(
        baseAssetCode: AssetCode('BTC'),
        quoteAssetCode: AssetCode('CHF'),
      );

      // Then
      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, isA<MarketPriceNotFoundFailure>());
    });

    test('returns typed not-found failure for an unavailable pair', () async {
      // Given
      final source = InMemoryMarketPriceDataSource();

      // When
      final result = await source.getLatest(
        baseAssetCode: AssetCode('BTC'),
        quoteAssetCode: AssetCode('USD'),
      );

      // Then
      expect(result.isFailure, isTrue);

      final failure = result.failureOrNull;

      expect(failure, isA<MarketPriceNotFoundFailure>());
      expect(failure!.type, MarketPriceNotFoundFailure.typeId);
      expect(failure.message, 'No market price is available for BTC/USD.');
    });

    test('rejects a request with identical base and quote assets', () async {
      // Given
      final source = InMemoryMarketPriceDataSource();
      final btc = AssetCode('BTC');

      // When / Then
      expect(
        () => source.getLatest(baseAssetCode: btc, quoteAssetCode: btc),
        throwsA(
          isA<ArgumentError>()
              .having((error) => error.name, 'name', 'quoteAssetCode')
              .having((error) => error.invalidValue, 'invalidValue', btc),
        ),
      );
    });

    test('rejects conflicting observations at the same effective instant', () {
      // Given
      final timestamp = DateTime.utc(2026, 9, 17, 10);

      final first = _observation(price: '65000', effectiveAt: timestamp);
      final conflicting = _observation(price: '65001', effectiveAt: timestamp);

      // When / Then
      expect(
        () => InMemoryMarketPriceDataSource(observations: [first, conflicting]),
        throwsA(
          isA<ArgumentError>().having(
            (error) => error.name,
            'name',
            'observations',
          ),
        ),
      );
    });

    test(
      'allows duplicate observations with the same price and timestamp',
      () async {
        // Given
        final timestamp = DateTime.utc(2026, 9, 17, 10);

        final first = _observation(price: '65000', effectiveAt: timestamp);
        final duplicate = _observation(price: '65000', effectiveAt: timestamp);

        final source = InMemoryMarketPriceDataSource(
          observations: [first, duplicate],
        );

        // When
        final result = await source.getLatest(
          baseAssetCode: AssetCode('BTC'),
          quoteAssetCode: AssetCode('USD'),
        );

        // Then
        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull!.price, Decimal.parse('65000'));
        expect(result.valueOrNull!.effectiveAt, timestamp);
      },
    );

    test('keeps asset-code casing significant', () async {
      // Given
      final source = InMemoryMarketPriceDataSource(
        observations: [
          _observation(
            baseAssetCode: 'BTC',
            quoteAssetCode: 'USD',
            price: '65000',
          ),
        ],
      );

      // When
      final result = await source.getLatest(
        baseAssetCode: AssetCode('btc'),
        quoteAssetCode: AssetCode('USD'),
      );

      // Then
      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, isA<MarketPriceNotFoundFailure>());
    });
  });
}

MarketPriceObservation _observation({
  String baseAssetCode = 'BTC',
  String quoteAssetCode = 'USD',
  String price = '65000',
  DateTime? effectiveAt,
}) {
  return MarketPriceObservation(
    baseAssetCode: AssetCode(baseAssetCode),
    quoteAssetCode: AssetCode(quoteAssetCode),
    price: Decimal.parse(price),
    effectiveAt: effectiveAt ?? DateTime.utc(2026, 9, 17, 10, 30),
  );
}
