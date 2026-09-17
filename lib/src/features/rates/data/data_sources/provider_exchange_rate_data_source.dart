import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/rates/data/clients/exchange_rate_provider_client.dart';
import 'package:axiom/src/features/rates/data/data_sources/exchange_rate_data_source.dart';
import 'package:axiom/src/features/rates/data/failures/exchange_rate_data_source_exception.dart';
import 'package:axiom/src/features/rates/data/models/exchange_rate_data_point.dart';
import 'package:axiom/src/features/rates/data/models/exchange_rate_provider_snapshot.dart';
import 'package:decimal/decimal.dart';

/// Exchange-rate data source backed by an external provider client.
///
/// The source normalizes provider rates into the application's canonical
/// orientation.
///
/// Assume the canonical quote currency is USD. The provider is requested using
/// USD as its base:
///
/// ```text
/// provider: 1 USD = 0.80 EUR
/// ```
///
/// The application persists the reciprocal:
///
/// ```text
/// 1 EUR = 1.25 USD
/// ```
///
/// This inversion is data-source normalization. Arbitrary pair inversion and
/// cross-rate calculation remain responsibilities of rate-domain services.
///
/// ## Determinism
///
/// Requested currencies and returned observations are sorted by normalized
/// currency code. Therefore output does not depend on the caller's iterable
/// ordering.
///
/// Division uses a fixed scale of 18 decimal places when a reciprocal has
/// infinite decimal precision.
final class ProviderExchangeRateDataSource implements ExchangeRateDataSource {
  /// Precision used when provider-rate inversion cannot terminate exactly.
  static const int divisionScale = 18;

  final ExchangeRateProviderClient _client;

  /// Creates a provider-backed exchange-rate data source.
  const ProviderExchangeRateDataSource({
    required ExchangeRateProviderClient client,
  }) : _client = client; // ignore: prefer_initializing_formals

  @override
  Future<List<ExchangeRateDataPoint>> fetchLatest({
    required Currency quoteCurrency,
    required Iterable<Currency> baseCurrencies,
  }) async {
    final quoteCode = _normalizeCurrencyCode(quoteCurrency.code.value);

    final requestedCurrencies = _normalizeRequestedCurrencies(
      quoteCurrency: quoteCurrency,
      quoteCode: quoteCode,
      baseCurrencies: baseCurrencies,
    );

    if (requestedCurrencies.isEmpty) {
      return const <ExchangeRateDataPoint>[];
    }

    final requestedCodes = requestedCurrencies
        .map((currency) => _normalizeCurrencyCode(currency.code.value))
        .toList(growable: false);

    final snapshot = await _client.fetchLatest(
      baseCurrencyCode: quoteCode,
      quoteCurrencyCodes: requestedCodes,
    );

    _validateSnapshotBase(snapshot: snapshot, expectedBaseCode: quoteCode);

    final providerRates = _normalizeProviderRates(snapshot);

    return List<ExchangeRateDataPoint>.unmodifiable(
      requestedCurrencies.map((currency) {
        final currencyCode = _normalizeCurrencyCode(currency.code.value);
        final providerValue = providerRates[currencyCode];

        if (providerValue == null) {
          throw MissingExchangeRateSourceValueException(
            currencyCode: currencyCode,
          );
        }

        if (providerValue <= Decimal.zero) {
          throw InvalidExchangeRateSourceValueException(
            currencyCode: currencyCode,
            value: providerValue,
          );
        }

        final normalizedRate = providerValue.inverse.toDecimal(
          scaleOnInfinitePrecision: divisionScale,
        );

        return ExchangeRateDataPoint(
          baseAssetId: currency.id,
          quoteAssetId: quoteCurrency.id,
          rate: normalizedRate,
          effectiveAt: snapshot.effectiveAt,
        );
      }),
    );
  }

  List<Currency> _normalizeRequestedCurrencies({
    required Currency quoteCurrency,
    required String quoteCode,
    required Iterable<Currency> baseCurrencies,
  }) {
    final currenciesByCode = <String, Currency>{};
    final seenAssetIds = <Object>{};

    for (final currency in baseCurrencies) {
      if (currency.id == quoteCurrency.id) {
        continue;
      }

      if (!seenAssetIds.add(currency.id)) {
        throw ArgumentError.value(
          currency.id,
          'baseCurrencies',
          'The same currency asset was supplied more than once.',
        );
      }

      final code = _normalizeCurrencyCode(currency.code.value);

      if (code == quoteCode) {
        throw ArgumentError.value(
          currency.code.value,
          'baseCurrencies',
          'A different currency asset uses the quote currency code $quoteCode.',
        );
      }

      final existing = currenciesByCode[code];
      if (existing != null) {
        throw ArgumentError.value(
          currency.code.value,
          'baseCurrencies',
          'Multiple currency assets normalize to provider code $code.',
        );
      }

      currenciesByCode[code] = currency;
    }

    final codes = currenciesByCode.keys.toList()..sort();

    return List<Currency>.unmodifiable(
      codes.map((code) => currenciesByCode[code]!),
    );
  }

  void _validateSnapshotBase({
    required ExchangeRateProviderSnapshot snapshot,
    required String expectedBaseCode,
  }) {
    final actualBaseCode = _normalizeCurrencyCode(snapshot.baseCurrencyCode);

    if (actualBaseCode != expectedBaseCode) {
      throw UnexpectedExchangeRateBaseCurrencyException(
        expectedCode: expectedBaseCode,
        actualCode: actualBaseCode,
      );
    }
  }

  Map<String, Decimal> _normalizeProviderRates(
    ExchangeRateProviderSnapshot snapshot,
  ) {
    final normalized = <String, Decimal>{};

    for (final entry in snapshot.quoteUnitsPerBaseUnit.entries) {
      final code = _normalizeCurrencyCode(entry.key);

      if (normalized.containsKey(code)) {
        throw DuplicateExchangeRateProviderCodeException(currencyCode: code);
      }

      normalized[code] = entry.value;
    }

    return normalized;
  }

  String _normalizeCurrencyCode(String value) {
    final normalized = value.trim().toUpperCase();

    if (!RegExp(r'^[A-Z]{3}$').hasMatch(normalized)) {
      throw ArgumentError.value(
        value,
        'currencyCode',
        'Currency code must contain exactly three ASCII letters.',
      );
    }

    return normalized;
  }
}
