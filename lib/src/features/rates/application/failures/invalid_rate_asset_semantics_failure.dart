import 'package:axiom/src/core/result/result.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'invalid_rate_asset_semantics_failure.mapper.dart';

/// Indicates that the assets referenced by a rate exist but their financial
/// types are incompatible with the concrete rate type.
///
/// Examples include:
///
/// - an ExchangeRate referencing a StockAsset; or
/// - a MarketPriceRate using a Currency as its priced base asset.
@MappableClass()
final class InvalidRateAssetSemanticsFailure
    extends Failure<InvalidRateAssetSemanticsFailure>
    with InvalidRateAssetSemanticsFailureMappable {
  /// Creates the failure.
  const InvalidRateAssetSemanticsFailure({required String message})
    : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'rates.invalidAssetSemantics';

  @override
  InvalidRateAssetSemanticsFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
