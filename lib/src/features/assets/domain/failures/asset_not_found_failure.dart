import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/domain/failures/asset_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'asset_not_found_failure.mapper.dart';

/// Indicates that an expected asset does not exist.
@MappableClass()
final class AssetNotFoundFailure extends Failure<AssetNotFoundFailure>
    with AssetNotFoundFailureMappable
    implements AssetFailure {
  /// Creates an asset-not-found failure with optional details.
  const AssetNotFoundFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'assets.assetNotFound';

  @override
  AssetNotFoundFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
