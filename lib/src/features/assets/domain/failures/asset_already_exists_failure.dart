import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/domain/failures/asset_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'asset_already_exists_failure.mapper.dart';

/// Indicates that an asset conflicts with an existing asset.
@MappableClass()
final class AssetAlreadyExistsFailure extends Failure<AssetAlreadyExistsFailure>
    with AssetAlreadyExistsFailureMappable
    implements AssetFailure {
  /// Creates an asset-already-exists failure with optional details.
  const AssetAlreadyExistsFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'assets.assetAlreadyExists';

  @override
  AssetAlreadyExistsFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
