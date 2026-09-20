import 'package:axiom/src/features/rates/data/data_sources/market_price_data_source.dart';
import 'package:mocktail/mocktail.dart';

/// A mock market-price data source for data-layer tests.
final class MockMarketPriceDataSource extends Mock
    implements MarketPriceDataSource {}
