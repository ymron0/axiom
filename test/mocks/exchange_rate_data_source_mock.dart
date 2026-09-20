import 'package:axiom/src/features/rates/data/data_sources/exchange_rate_data_source.dart';
import 'package:mocktail/mocktail.dart';

/// A mock exchange-rate data source for data-layer tests.
final class MockExchangeRateDataSource extends Mock
    implements ExchangeRateDataSource {}
