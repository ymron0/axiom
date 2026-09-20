@Tags(['data'])
library;

import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/rates/application/failures/rate_source_acquisition_failure.dart';
import 'package:axiom/src/features/rates/data/adapters/exchange_rate_source_adapter_impl.dart';
import 'package:axiom/src/features/rates/data/exceptions/exchange_rate_data_source_exception.dart';
import 'package:axiom/src/features/rates/data/models/exchange_rate_data_point.dart';
import 'package:decimal/decimal.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/assets/asset_fixtures.dart';
import '../../../../../mocks/exchange_rate_data_source_mock.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(currencyFixture());
  });

  group('ExchangeRateSourceAdapterImpl', () {
    late MockExchangeRateDataSource dataSource;
    late ExchangeRateSourceAdapterImpl adapter;
    late Currency eur;
    late Currency usd;

    setUp(() {
      dataSource = MockExchangeRateDataSource();
      adapter = ExchangeRateSourceAdapterImpl(dataSource: dataSource);
      eur = currencyFixture(id: 'asset-eur', code: 'EUR');
      usd = currencyFixture(id: 'asset-usd', code: 'USD');
    });

    test('returns normalized rate observation on successful fetch', () async {
      // Given
      final effectiveAt = DateTime.utc(2026, 9, 20, 10);
      final rate = Decimal.parse('1.0850');
      final dataPoint = ExchangeRateDataPoint(
        baseAssetId: eur.id,
        quoteAssetId: usd.id,
        rate: rate,
        effectiveAt: effectiveAt,
      );
      when(
        () => dataSource.fetchLatest(
          quoteCurrency: usd,
          baseCurrencies: [eur],
        ),
      ).thenAnswer((_) async => [dataPoint]);

      // When
      final result = await adapter.fetchLatest(
        baseCurrency: eur,
        quoteCurrency: usd,
      );

      // Then
      expect(result.isSuccess, isTrue);
      final observation = result.valueOrNull!;
      expect(observation.rate, rate);
      expect(observation.effectiveAt, effectiveAt);
      verify(
        () => dataSource.fetchLatest(
          quoteCurrency: usd,
          baseCurrencies: [eur],
        ),
      ).called(1);
    });

    test(
      'returns RateSourceAcquisitionFailure when data source throws an exception',
      () async {
        // Given
        when(
          () => dataSource.fetchLatest(
            quoteCurrency: any(named: 'quoteCurrency'),
            baseCurrencies: any(named: 'baseCurrencies'),
          ),
        ).thenThrow(
          MissingExchangeRateSourceValueException(currencyCode: 'USD'),
        );

        // When
        final result = await adapter.fetchLatest(
          baseCurrency: eur,
          quoteCurrency: usd,
        );

        // Then
        expect(result.isFailure, isTrue);
        final failure = result.failureOrNull;
        expect(failure, isA<RateSourceAcquisitionFailure>());
        expect(
          failure!.message,
          'The provider did not return an exchange rate for USD.',
        );
      },
    );

    test(
      'returns RateSourceAcquisitionFailure when observation list is empty',
      () async {
        // Given
        when(
          () => dataSource.fetchLatest(
            quoteCurrency: usd,
            baseCurrencies: [eur],
          ),
        ).thenAnswer((_) async => []);

        // When
        final result = await adapter.fetchLatest(
          baseCurrency: eur,
          quoteCurrency: usd,
        );

        // Then
        expect(result.isFailure, isTrue);
        final failure = result.failureOrNull;
        expect(failure, isA<RateSourceAcquisitionFailure>());
        expect(
          failure!.message,
          'Expected exactly one exchange-rate observation for EUR/USD, '
          'but received 0.',
        );
      },
    );

    test(
      'returns RateSourceAcquisitionFailure when multiple observations returned',
      () async {
        // Given
        final dataPoint = ExchangeRateDataPoint(
          baseAssetId: eur.id,
          quoteAssetId: usd.id,
          rate: Decimal.parse('1.0850'),
          effectiveAt: DateTime.utc(2026, 9, 20),
        );
        when(
          () => dataSource.fetchLatest(
            quoteCurrency: usd,
            baseCurrencies: [eur],
          ),
        ).thenAnswer((_) async => [dataPoint, dataPoint]);

        // When
        final result = await adapter.fetchLatest(
          baseCurrency: eur,
          quoteCurrency: usd,
        );

        // Then
        expect(result.isFailure, isTrue);
        final failure = result.failureOrNull;
        expect(failure, isA<RateSourceAcquisitionFailure>());
        expect(
          failure!.message,
          'Expected exactly one exchange-rate observation for EUR/USD, '
          'but received 2.',
        );
      },
    );

    test(
      'returns RateSourceAcquisitionFailure when observation has unexpected base asset',
      () async {
        // Given
        final wrongBase = AssetId.fromString('asset-gbp');
        final dataPoint = ExchangeRateDataPoint(
          baseAssetId: wrongBase,
          quoteAssetId: usd.id,
          rate: Decimal.parse('1.30'),
          effectiveAt: DateTime.utc(2026, 9, 20),
        );
        when(
          () => dataSource.fetchLatest(
            quoteCurrency: usd,
            baseCurrencies: [eur],
          ),
        ).thenAnswer((_) async => [dataPoint]);

        // When
        final result = await adapter.fetchLatest(
          baseCurrency: eur,
          quoteCurrency: usd,
        );

        // Then
        expect(result.isFailure, isTrue);
        final failure = result.failureOrNull;
        expect(failure, isA<RateSourceAcquisitionFailure>());
        expect(
          failure!.message,
          'Exchange-rate source returned an unexpected asset pair for EUR/USD.',
        );
      },
    );

    test(
      'returns RateSourceAcquisitionFailure when observation has unexpected quote asset',
      () async {
        // Given
        final wrongQuote = AssetId.fromString('asset-cad');
        final dataPoint = ExchangeRateDataPoint(
          baseAssetId: eur.id,
          quoteAssetId: wrongQuote,
          rate: Decimal.parse('1.45'),
          effectiveAt: DateTime.utc(2026, 9, 20),
        );
        when(
          () => dataSource.fetchLatest(
            quoteCurrency: usd,
            baseCurrencies: [eur],
          ),
        ).thenAnswer((_) async => [dataPoint]);

        // When
        final result = await adapter.fetchLatest(
          baseCurrency: eur,
          quoteCurrency: usd,
        );

        // Then
        expect(result.isFailure, isTrue);
        final failure = result.failureOrNull;
        expect(failure, isA<RateSourceAcquisitionFailure>());
        expect(
          failure!.message,
          'Exchange-rate source returned an unexpected asset pair for EUR/USD.',
        );
      },
    );
  });
}
