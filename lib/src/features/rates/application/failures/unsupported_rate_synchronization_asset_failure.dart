import 'package:axiom/src/core/result/result.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'unsupported_rate_synchronization_asset_failure.mapper.dart';

/// Indicates that exchange-rate synchronization received a non-currency asset.
@MappableClass()
final class UnsupportedRateSynchronizationAssetFailure
    extends Failure<UnsupportedRateSynchronizationAssetFailure>
    with UnsupportedRateSynchronizationAssetFailureMappable {
  /// Creates the failure.
  const UnsupportedRateSynchronizationAssetFailure({required String message})
    : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'rates.synchronization.unsupportedAsset';

  @override
  UnsupportedRateSynchronizationAssetFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
