part of 'exchange_rate_data_source_exception.dart';

/// Indicates that two provider keys collapse to the same normalized code.
final class DuplicateExchangeRateProviderCodeException
    extends ExchangeRateDataSourceException {
  /// Duplicated normalized currency code.
  final String currencyCode;

  /// Creates a duplicate-provider-code exception.
  DuplicateExchangeRateProviderCodeException({required this.currencyCode})
    : super('The provider returned duplicate currency code $currencyCode.');
}
