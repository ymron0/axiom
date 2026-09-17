import 'package:decimal/decimal.dart';

/// Raw exchange-rate snapshot returned by an external provider.
///
/// Provider orientation is:
///
/// ```text
/// 1 baseCurrencyCode
///   = quoteUnitsPerBaseUnit[quoteCode] × quoteCode
/// ```
///
/// For example:
///
/// ```text
/// baseCurrencyCode = USD
/// EUR = 0.80
/// ```
///
/// means:
///
/// ```text
/// 1 USD = 0.80 EUR
/// ```
///
/// The exchange-rate data source is responsible for converting this into the
/// application's canonical persisted orientation when required.
final class ExchangeRateProviderSnapshot {
  /// Provider-reported base currency code.
  final String baseCurrencyCode;

  /// Provider quote values keyed by provider currency code.
  final Map<String, Decimal> quoteUnitsPerBaseUnit;

  /// Financial instant represented by the snapshot.
  final DateTime effectiveAt;

  /// Creates a provider snapshot.
  ///
  /// No provider-specific normalization is performed here. Keeping this model
  /// close to the raw provider response allows the data source to validate and
  /// normalize provider data explicitly.
  ExchangeRateProviderSnapshot({
    required this.baseCurrencyCode,
    required Map<String, Decimal> quoteUnitsPerBaseUnit,
    required DateTime effectiveAt,
  }) : quoteUnitsPerBaseUnit = Map.unmodifiable(quoteUnitsPerBaseUnit),
       effectiveAt = effectiveAt.toUtc();
}