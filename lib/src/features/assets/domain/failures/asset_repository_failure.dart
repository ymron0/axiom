import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/domain/failures/asset_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'asset_repository_failure.mapper.dart';

/// Indicates that an asset repository operation could not complete.
@MappableClass()
final class AssetRepositoryFailure extends Failure<AssetRepositoryFailure>
    with AssetRepositoryFailureMappable
    implements AssetFailure {
  /// Creates an asset repository failure with optional details.
  const AssetRepositoryFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'assets.repository';

  @override
  AssetRepositoryFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
