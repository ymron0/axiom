import 'package:axiom/src/core/result/result.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'invalid_trade_asset_failure.mapper.dart';

/// Indicates that a buy or sell transaction uses an invalid traded asset.
///
/// Buy and sell transactions represent acquisition or disposal of a non-cash
/// asset. A fiat currency therefore cannot be the traded asset.
///
/// Settlement eligibility is validated separately through the existing
/// payment-asset rules.
@MappableClass()
final class InvalidTradeAssetFailure extends Failure<InvalidTradeAssetFailure>
    with InvalidTradeAssetFailureMappable {
  /// Stable identifier for this failure kind.
  static const typeId = 'application.invalidTradeAsset';

  /// Creates the failure.
  const InvalidTradeAssetFailure({required String message}) : super(message);

  @override
  InvalidTradeAssetFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
