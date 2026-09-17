part of 'exchange_rate_data_source_exception.dart';

/// Indicates that the provider returned a snapshot for an unexpected base.
final class UnexpectedExchangeRateBaseCurrencyException
    extends ExchangeRateDataSourceException {
  /// Base currency requested from the provider.
  final String expectedCode;

  /// Base currency reported by the provider.
  final String actualCode;

  /// Creates an unexpected-base-currency exception.
  UnexpectedExchangeRateBaseCurrencyException({
    required this.expectedCode,
    required this.actualCode,
  }) : super(
         'Expected provider base currency $expectedCode, '
         'but received $actualCode.',
       );
}
