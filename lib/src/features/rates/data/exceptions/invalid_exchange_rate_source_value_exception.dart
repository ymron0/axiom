part of 'exchange_rate_data_source_exception.dart';

/// Indicates that a provider returned a zero or negative exchange rate.
final class InvalidExchangeRateSourceValueException
    extends ExchangeRateDataSourceException {
  /// Provider currency code associated with the invalid value.
  final String currencyCode;

  /// Invalid provider value.
  final Decimal value;

  /// Creates an invalid-rate exception.
  InvalidExchangeRateSourceValueException({
    required this.currencyCode,
    required this.value,
  }) : super(
         'The provider returned an invalid exchange rate for '
         '$currencyCode: $value.',
       );
}
