part of 'exchange_rate_data_source_exception.dart';

/// Indicates that a requested currency was absent from the provider response.
final class MissingExchangeRateSourceValueException
    extends ExchangeRateDataSourceException {
  /// Missing provider currency code.
  final String currencyCode;

  /// Creates a missing-rate exception.
  MissingExchangeRateSourceValueException({required this.currencyCode})
    : super('The provider did not return an exchange rate for $currencyCode.');
}
