import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_code.dart';
import 'package:axiom/src/features/rates/data/clients/exchange_rate_provider_client.dart';
import 'package:axiom/src/features/rates/data/data_sources/provider_exchange_rate_data_source.dart';
import 'package:axiom/src/features/rates/data/exceptions/exchange_rate_data_source_exception.dart';
import 'package:axiom/src/features/rates/data/models/exchange_rate_provider_snapshot.dart';
import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

void main() {
  group('ProviderExchangeRateDataSource', () {
    late FakeExchangeRateProviderClient client;
    late ProviderExchangeRateDataSource dataSource;

    late Currency usd;
    late Currency eur;
    late Currency chf;

    setUp(() {
      client = FakeExchangeRateProviderClient();
      dataSource = ProviderExchangeRateDataSource(client: client);

      usd = createCurrency(id: 'asset-usd', code: 'USD', name: 'US Dollar');

      eur = createCurrency(id: 'asset-eur', code: 'EUR', name: 'Euro');

      chf = createCurrency(id: 'asset-chf', code: 'CHF', name: 'Swiss Franc');
    });

    test('requests provider using quote currency as provider base', () async {
      // Given
      client.response = createSnapshot(rates: {'EUR': '0.80', 'CHF': '0.50'});

      // When
      await dataSource.fetchLatest(
        quoteCurrency: usd,
        baseCurrencies: [eur, chf],
      );

      // Then
      expect(client.callCount, 1);
      expect(client.lastBaseCurrencyCode, 'USD');
      expect(client.lastQuoteCurrencyCodes, ['CHF', 'EUR']);
    });

    test('inverts provider rates into canonical quote orientation', () async {
      // Given
      //
      // Provider:
      //
      // 1 USD = 0.80 EUR
      // 1 USD = 0.50 CHF
      //
      // Normalized:
      //
      // 1 EUR = 1.25 USD
      // 1 CHF = 2 USD
      client.response = createSnapshot(rates: {'EUR': '0.80', 'CHF': '0.50'});

      // When
      final result = await dataSource.fetchLatest(
        quoteCurrency: usd,
        baseCurrencies: [eur, chf],
      );

      // Then
      expect(result, hasLength(2));

      expect(result[0].baseAssetId, chf.id);
      expect(result[0].quoteAssetId, usd.id);
      expect(result[0].rate, Decimal.parse('2'));

      expect(result[1].baseAssetId, eur.id);
      expect(result[1].quoteAssetId, usd.id);
      expect(result[1].rate, Decimal.parse('1.25'));
    });

    test('preserves internal asset identities', () async {
      // Given
      client.response = createSnapshot(rates: {'EUR': '0.80'});

      // When
      final result = await dataSource.fetchLatest(
        quoteCurrency: usd,
        baseCurrencies: [eur],
      );

      // Then
      expect(result.single.baseAssetId, eur.id);
      expect(result.single.quoteAssetId, usd.id);
    });

    test('returns results in deterministic currency-code order', () async {
      // Given
      client.response = createSnapshot(rates: {'EUR': '0.80', 'CHF': '0.50'});

      // When
      final result = await dataSource.fetchLatest(
        quoteCurrency: usd,
        baseCurrencies: [eur, chf],
      );

      // Then
      expect(result.map((dataPoint) => dataPoint.baseAssetId), [
        chf.id,
        eur.id,
      ]);
    });

    test('result order does not depend on input order', () async {
      // Given
      client.response = createSnapshot(rates: {'EUR': '0.80', 'CHF': '0.50'});

      // When
      final first = await dataSource.fetchLatest(
        quoteCurrency: usd,
        baseCurrencies: [eur, chf],
      );

      final second = await dataSource.fetchLatest(
        quoteCurrency: usd,
        baseCurrencies: [chf, eur],
      );

      // Then
      expect(
        first.map((dataPoint) => dataPoint.baseAssetId),
        second.map((dataPoint) => dataPoint.baseAssetId),
      );
    });

    test('uses deterministic precision for infinite reciprocal', () async {
      // Given
      client.response = createSnapshot(rates: {'EUR': '3'});

      // When
      final result = await dataSource.fetchLatest(
        quoteCurrency: usd,
        baseCurrencies: [eur],
      );

      // Then
      expect(result.single.rate, Decimal.parse('0.333333333333333333'));
    });

    test('preserves snapshot effective time', () async {
      // Given
      final effectiveAt = DateTime.utc(2026, 9, 16, 22, 15);

      client.response = createSnapshot(
        rates: {'EUR': '0.80'},
        effectiveAt: effectiveAt,
      );

      // When
      final result = await dataSource.fetchLatest(
        quoteCurrency: usd,
        baseCurrencies: [eur],
      );

      // Then
      expect(result.single.effectiveAt, effectiveAt);
    });

    test('normalizes currency codes before calling provider', () async {
      // Given
      final lowerUsd = createCurrency(
        id: 'asset-usd',
        code: 'usd',
        name: 'US Dollar',
      );

      final lowerEur = createCurrency(
        id: 'asset-eur',
        code: 'eur',
        name: 'Euro',
      );

      client.response = createSnapshot(baseCode: 'usd', rates: {'eur': '0.80'});

      // When
      await dataSource.fetchLatest(
        quoteCurrency: lowerUsd,
        baseCurrencies: [lowerEur],
      );

      // Then
      expect(client.lastBaseCurrencyCode, 'USD');
      expect(client.lastQuoteCurrencyCodes, ['EUR']);
    });

    test('ignores quote asset when included in base currencies', () async {
      // Given
      client.response = createSnapshot(rates: {'EUR': '0.80'});

      // When
      final result = await dataSource.fetchLatest(
        quoteCurrency: usd,
        baseCurrencies: [usd, eur],
      );

      // Then
      expect(result, hasLength(1));
      expect(result.single.baseAssetId, eur.id);
      expect(client.lastQuoteCurrencyCodes, ['EUR']);
    });

    test(
      'returns empty list without calling provider when no bases remain',
      () async {
        // When
        final result = await dataSource.fetchLatest(
          quoteCurrency: usd,
          baseCurrencies: [usd],
        );

        // Then
        expect(result, isEmpty);
        expect(client.callCount, 0);
      },
    );

    test('returns immutable result list', () async {
      // Given
      client.response = createSnapshot(rates: {'EUR': '0.80'});

      final result = await dataSource.fetchLatest(
        quoteCurrency: usd,
        baseCurrencies: [eur],
      );

      // When
      void operation() {
        result.clear();
      }

      // Then
      expect(operation, throwsUnsupportedError);
    });

    test('rejects duplicated asset identity', () async {
      // Given
      final duplicate = createCurrency(
        id: 'asset-eur',
        code: 'GBP',
        name: 'Pound Sterling',
      );

      // When
      final operation = dataSource.fetchLatest(
        quoteCurrency: usd,
        baseCurrencies: [eur, duplicate],
      );

      // Then
      await expectLater(
        operation,
        throwsA(
          isA<ArgumentError>()
              .having((error) => error.name, 'name', 'baseCurrencies')
              .having((error) => error.invalidValue, 'invalidValue', eur.id),
        ),
      );

      expect(client.callCount, 0);
    });

    test(
      'rejects different assets with same normalized provider code',
      () async {
        // Given
        final duplicateEur = createCurrency(
          id: 'asset-other-eur',
          code: 'eur',
          name: 'Other Euro',
        );

        // When
        final operation = dataSource.fetchLatest(
          quoteCurrency: usd,
          baseCurrencies: [eur, duplicateEur],
        );

        // Then
        await expectLater(
          operation,
          throwsA(
            isA<ArgumentError>().having(
              (error) => error.name,
              'name',
              'baseCurrencies',
            ),
          ),
        );

        expect(client.callCount, 0);
      },
    );

    test(
      'rejects different asset using quote currency provider code',
      () async {
        // Given
        final otherUsd = createCurrency(
          id: 'asset-other-usd',
          code: 'usd',
          name: 'Other US Dollar',
        );

        // When
        final operation = dataSource.fetchLatest(
          quoteCurrency: usd,
          baseCurrencies: [otherUsd],
        );

        // Then
        await expectLater(
          operation,
          throwsA(
            isA<ArgumentError>().having(
              (error) => error.name,
              'name',
              'baseCurrencies',
            ),
          ),
        );

        expect(client.callCount, 0);
      },
    );

    test('rejects unexpected provider base currency', () async {
      // Given
      client.response = createSnapshot(baseCode: 'EUR', rates: {'CHF': '0.90'});

      // When
      final operation = dataSource.fetchLatest(
        quoteCurrency: usd,
        baseCurrencies: [chf],
      );

      // Then
      await expectLater(
        operation,
        throwsA(
          isA<UnexpectedExchangeRateBaseCurrencyException>()
              .having(
                (exception) => exception.expectedCode,
                'expectedCode',
                'USD',
              )
              .having((exception) => exception.actualCode, 'actualCode', 'EUR'),
        ),
      );
    });

    test('rejects missing requested provider rate', () async {
      // Given
      client.response = createSnapshot(rates: const {});

      // When
      final operation = dataSource.fetchLatest(
        quoteCurrency: usd,
        baseCurrencies: [eur],
      );

      // Then
      await expectLater(
        operation,
        throwsA(
          isA<MissingExchangeRateSourceValueException>().having(
            (exception) => exception.currencyCode,
            'currencyCode',
            'EUR',
          ),
        ),
      );
    });

    test('rejects zero provider rate', () async {
      // Given
      client.response = createSnapshot(rates: {'EUR': '0'});

      // When
      final operation = dataSource.fetchLatest(
        quoteCurrency: usd,
        baseCurrencies: [eur],
      );

      // Then
      await expectLater(
        operation,
        throwsA(
          isA<InvalidExchangeRateSourceValueException>()
              .having(
                (exception) => exception.currencyCode,
                'currencyCode',
                'EUR',
              )
              .having((exception) => exception.value, 'value', Decimal.zero),
        ),
      );
    });

    test('rejects negative provider rate', () async {
      // Given
      final invalidValue = Decimal.parse('-0.01');

      client.response = createSnapshot(rates: {'EUR': '-0.01'});

      // When
      final operation = dataSource.fetchLatest(
        quoteCurrency: usd,
        baseCurrencies: [eur],
      );

      // Then
      await expectLater(
        operation,
        throwsA(
          isA<InvalidExchangeRateSourceValueException>()
              .having(
                (exception) => exception.currencyCode,
                'currencyCode',
                'EUR',
              )
              .having((exception) => exception.value, 'value', invalidValue),
        ),
      );
    });

    test('rejects duplicate provider codes after normalization', () async {
      // Given
      client.response = createSnapshot(rates: {'EUR': '0.80', ' eur ': '0.81'});

      // When
      final operation = dataSource.fetchLatest(
        quoteCurrency: usd,
        baseCurrencies: [eur],
      );

      // Then
      await expectLater(
        operation,
        throwsA(
          isA<DuplicateExchangeRateProviderCodeException>().having(
            (exception) => exception.currencyCode,
            'currencyCode',
            'EUR',
          ),
        ),
      );
    });

    test('rejects invalid provider base currency code', () async {
      // Given
      client.response = createSnapshot(baseCode: 'EU', rates: {'EUR': '0.80'});

      // When
      final operation = dataSource.fetchLatest(
        quoteCurrency: usd,
        baseCurrencies: [eur],
      );

      // Then
      await expectLater(
        operation,
        throwsA(
          isA<ArgumentError>()
              .having((error) => error.name, 'name', 'currencyCode')
              .having((error) => error.invalidValue, 'invalidValue', 'EU'),
        ),
      );
    });

    test('rejects invalid provider quote currency code', () async {
      // Given
      client.response = createSnapshot(
        rates: {'EUR': '0.80', 'INVALID': '1.00'},
      );

      // When
      final operation = dataSource.fetchLatest(
        quoteCurrency: usd,
        baseCurrencies: [eur],
      );

      // Then
      await expectLater(
        operation,
        throwsA(
          isA<ArgumentError>()
              .having((error) => error.name, 'name', 'currencyCode')
              .having((error) => error.invalidValue, 'invalidValue', 'INVALID'),
        ),
      );
    });
  });
}

Currency createCurrency({
  required String id,
  required String code,
  required String name,
}) {
  final timestamp = DateTime.utc(2026, 9, 17);

  return Currency(
    id: AssetId.fromString(id),
    entityVersion: 1,
    createdAt: timestamp,
    modifiedAt: timestamp,
    name: name,
    code: AssetCode(code),
    decimalPlaces: 2,
  );
}

ExchangeRateProviderSnapshot createSnapshot({
  String baseCode = 'USD',
  required Map<String, String> rates,
  DateTime? effectiveAt,
}) {
  return ExchangeRateProviderSnapshot(
    baseCurrencyCode: baseCode,
    quoteUnitsPerBaseUnit: {
      for (final entry in rates.entries) entry.key: Decimal.parse(entry.value),
    },
    effectiveAt: effectiveAt ?? DateTime.utc(2026, 9, 17, 8),
  );
}

final class FakeExchangeRateProviderClient
    implements ExchangeRateProviderClient {
  ExchangeRateProviderSnapshot? response;

  int callCount = 0;
  String? lastBaseCurrencyCode;
  List<String>? lastQuoteCurrencyCodes;

  @override
  Future<ExchangeRateProviderSnapshot> fetchLatest({
    required String baseCurrencyCode,
    required List<String> quoteCurrencyCodes,
  }) async {
    callCount++;
    lastBaseCurrencyCode = baseCurrencyCode;
    lastQuoteCurrencyCodes = List.unmodifiable(quoteCurrencyCodes);

    final configuredResponse = response;

    if (configuredResponse == null) {
      throw StateError('Fake provider response was not configured.');
    }

    return configuredResponse;
  }
}
