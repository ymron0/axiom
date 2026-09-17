import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/rates/data/failures/market_price_data_source_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'market_price_invalid_response_failure.mapper.dart';

/// Indicates that a market-price provider responded successfully at the
/// transport level but returned data that cannot be represented safely.
///
/// Examples include:
///
/// - a missing price;
/// - a zero or negative price;
/// - malformed decimal data;
/// - an invalid timestamp; or
/// - a response referring to an unexpected asset pair.
///
/// This failure is intended for concrete external-provider adapters.
/// Domain invariants must never be weakened to accommodate malformed provider
/// data.
@MappableClass()
final class MarketPriceInvalidResponseFailure
    extends Failure<MarketPriceInvalidResponseFailure>
    with MarketPriceInvalidResponseFailureMappable
    implements MarketPriceDataSourceFailure {
  /// Creates an invalid-response failure with optional details.
  const MarketPriceInvalidResponseFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'rates.marketPriceSource.invalidResponse';

  @override
  MarketPriceInvalidResponseFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
