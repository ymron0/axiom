import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/domain/failures/asset_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'asset_persistence_failure.mapper.dart';

/// Indicates that asset persistence could not complete successfully.
///
/// This failure represents storage-level problems exposed through the Assets
/// domain failure contract.
///
/// Infrastructure-specific failures and exceptions must not escape through
/// `AssetRepository`. Persistent repository implementations translate expected
/// storage problems into this failure instead.
///
/// Programmer errors and violated internal assumptions are not translated into
/// this failure and should continue to propagate normally.
@MappableClass()
final class AssetPersistenceFailure extends Failure<AssetPersistenceFailure>
    with AssetPersistenceFailureMappable
    implements AssetFailure {
  /// Creates an asset-persistence failure with optional details.
  const AssetPersistenceFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'assets.persistence';

  @override
  AssetPersistenceFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
