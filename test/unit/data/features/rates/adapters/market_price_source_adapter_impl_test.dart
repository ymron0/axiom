@Tags(['data'])
library;

import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_code.dart';
import 'package:axiom/src/features/rates/application/failures/rate_source_acquisition_failure.dart';
import 'package:axiom/src/features/rates/data/adapters/market_price_source_adapter_impl.dart';
import 'package:axiom/src/features/rates/data/failures/market_price_invalid_response_failure.dart';
import 'package:axiom/src/features/rates/data/failures/market_price_not_found_failure.dart';
import 'package:axiom/src/features/rates/data/failures/market_price_source_unavailable_failure.dart';
import 'package:axiom/src/features/rates/data/models/market_price_observation.dart';
import 'package:decimal/decimal.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/assets/asset_fixtures.dart';
import '../../../../../mocks/market_price_data_source_mock.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(AssetCode('BTC'));
    registerFallbackValue(AssetCode('USD'));
  });

  group('MarketPriceSourceAdapterImpl', () {
    late MockMarketPriceDataSource dataSource;
    late MarketPriceSourceAdapterImpl adapter;
    late CryptoAsset btc;
    late Currency usd;

    setUp(() {
      dataSource = MockMarketPriceDataSource();
      adapter = MarketPriceSourceAdapterImpl(dataSource: dataSource);
      btc = cryptoAssetFixture(id: 'asset-btc', code: 'BTC');
      usd = currencyFixture(id: 'asset-usd', code: 'USD');
    });

    test('returns normalized rate observation on successful fetch', () async {
      // Given
      final effectiveAt = DateTime.utc(2026, 9, 20, 8);
      final price = Decimal.parse('64500.25');
      final observation = MarketPriceObservation(
        baseAssetCode: AssetCode('BTC'),
        quoteAssetCode: AssetCode('USD'),
        price: price,
        effectiveAt: effectiveAt,
      );
      when(
        () => dataSource.getLatest(
          baseAssetCode: AssetCode('BTC'),
          quoteAssetCode: AssetCode('USD'),
        ),
      ).thenAnswer((_) async => Success(observation));

      // When
      final result = await adapter.fetchLatest(
        baseAsset: btc,
        quoteCurrency: usd,
      );

      // Then
      expect(result.isSuccess, isTrue);
      final rateObservation = result.valueOrNull!;
      expect(rateObservation.rate, price);
      expect(rateObservation.effectiveAt, effectiveAt);
      verify(
        () => dataSource.getLatest(
          baseAssetCode: AssetCode('BTC'),
          quoteAssetCode: AssetCode('USD'),
        ),
      ).called(1);
    });

    test('throws ArgumentError when baseAsset is a Currency', () {
      // Given
      final eur = currencyFixture(id: 'asset-eur', code: 'EUR');

      // When / Then
      expect(
        () => adapter.fetchLatest(baseAsset: eur, quoteCurrency: usd),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            'Currency assets must use the exchange-rate source.',
          ),
        ),
      );
      verifyZeroInteractions(dataSource);
    });

    test(
      'translates data-source failure with message to RateSourceAcquisitionFailure',
      () async {
        // Given
        const failure = MarketPriceNotFoundFailure(
          message: 'Market price for BTC/USD is missing',
        );
        when(
          () => dataSource.getLatest(
            baseAssetCode: AssetCode('BTC'),
            quoteAssetCode: AssetCode('USD'),
          ),
        ).thenAnswer((_) async => failure);

        // When
        final result = await adapter.fetchLatest(
          baseAsset: btc,
          quoteCurrency: usd,
        );

        // Then
        expect(result.isFailure, isTrue);
        final acquisitionFailure = result.failureOrNull;
        expect(acquisitionFailure, isA<RateSourceAcquisitionFailure>());
        expect(
          acquisitionFailure!.message,
          'Market price for BTC/USD is missing',
        );
      },
    );

    test(
      'translates data-source failure with null message to fallback message',
      () async {
        // Given
        const failure = MarketPriceNotFoundFailure();
        when(
          () => dataSource.getLatest(
            baseAssetCode: AssetCode('BTC'),
            quoteAssetCode: AssetCode('USD'),
          ),
        ).thenAnswer((_) async => failure);

        // When
        final result = await adapter.fetchLatest(
          baseAsset: btc,
          quoteCurrency: usd,
        );

        // Then
        expect(result.isFailure, isTrue);
        final acquisitionFailure = result.failureOrNull;
        expect(acquisitionFailure, isA<RateSourceAcquisitionFailure>());
        expect(
          acquisitionFailure!.message,
          'Market-price source failed with rates.marketPriceSource.notFound.',
        );
      },
    );

    test(
      'translates source-unavailable failure into RateSourceAcquisitionFailure',
      () async {
        // Given
        const failure = MarketPriceSourceUnavailableFailure(
          message: 'Remote market price server unreachable',
        );
        when(
          () => dataSource.getLatest(
            baseAssetCode: any(named: 'baseAssetCode'),
            quoteAssetCode: any(named: 'quoteAssetCode'),
          ),
        ).thenAnswer((_) async => failure);

        // When
        final result = await adapter.fetchLatest(
          baseAsset: btc,
          quoteCurrency: usd,
        );

        // Then
        expect(result.failureOrNull, isA<RateSourceAcquisitionFailure>());
        expect(
          result.failureOrNull!.message,
          'Remote market price server unreachable',
        );
      },
    );

    test(
      'translates invalid-response failure into RateSourceAcquisitionFailure',
      () async {
        // Given
        const failure = MarketPriceInvalidResponseFailure(
          message: 'Malformed JSON payload',
        );
        when(
          () => dataSource.getLatest(
            baseAssetCode: any(named: 'baseAssetCode'),
            quoteAssetCode: any(named: 'quoteAssetCode'),
          ),
        ).thenAnswer((_) async => failure);

        // When
        final result = await adapter.fetchLatest(
          baseAsset: btc,
          quoteCurrency: usd,
        );

        // Then
        expect(result.failureOrNull, isA<RateSourceAcquisitionFailure>());
        expect(result.failureOrNull!.message, 'Malformed JSON payload');
      },
    );
  });
}
