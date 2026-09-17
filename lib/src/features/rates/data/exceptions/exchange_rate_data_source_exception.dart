import 'package:decimal/decimal.dart';

part 'duplicate_exchange_rate_provider_code_exception.dart';
part 'invalid_exchange_rate_source_value_exception.dart';
part 'missing_exchange_rate_source_value_exception.dart';
part 'unexpected_exchange_rate_base_currency_exception.dart';

/// Base exception for expected invalid or incomplete exchange-rate source data.
sealed class ExchangeRateDataSourceException implements Exception {
  /// Human-readable explanation of the source failure.
  final String message;

  /// Creates an exchange-rate source exception.
  const ExchangeRateDataSourceException(this.message);

  @override
  String toString() => '$runtimeType: $message';
}
