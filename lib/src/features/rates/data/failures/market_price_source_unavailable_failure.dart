import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/rates/data/failures/market_price_data_source_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'market_price_source_unavailable_failure.mapper.dart';

/// Indicates that the market-price provider could not be reached or could not
/// complete the requested operation.
///
/// Typical causes include network failures, provider outages, timeouts, and
/// temporary provider-side errors.
///
/// Provider-specific exceptions must not escape through the
/// [MarketPriceDataSourceFailure] boundary when they represent expected
/// acquisition failures.
@MappableClass()
final class MarketPriceSourceUnavailableFailure
    extends Failure<MarketPriceSourceUnavailableFailure>
    with MarketPriceSourceUnavailableFailureMappable
    implements MarketPriceDataSourceFailure {
  /// Creates a source-unavailable failure with optional details.
  const MarketPriceSourceUnavailableFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'rates.marketPriceSource.unavailable';

  @override
  MarketPriceSourceUnavailableFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
