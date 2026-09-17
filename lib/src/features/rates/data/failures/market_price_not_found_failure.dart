import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/rates/data/failures/market_price_data_source_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'market_price_not_found_failure.mapper.dart';

/// Indicates that the source has no market-price observation for the requested
/// ordered asset pair.
///
/// This failure does not imply that the reverse pair exists and callers must
/// not automatically interpret it as permission to invert another price.
@MappableClass()
final class MarketPriceNotFoundFailure
    extends Failure<MarketPriceNotFoundFailure>
    with MarketPriceNotFoundFailureMappable
    implements MarketPriceDataSourceFailure {
  /// Creates a market-price-not-found failure with optional details.
  const MarketPriceNotFoundFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'rates.marketPriceSource.notFound';

  @override
  MarketPriceNotFoundFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
