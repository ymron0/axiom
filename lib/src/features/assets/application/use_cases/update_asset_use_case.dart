import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/assets/domain/repositories/asset_repository.dart';

/// Updates one stored asset through the asset repository.
///
/// Example: `final result = await UpdateAssetUseCase(repository).call(asset);`
class UpdateAssetUseCase {
  /// Creates a use case backed by [repository].
  UpdateAssetUseCase(this._repository);

  final AssetRepository _repository;

  /// Replaces the stored asset and returns it, or the repository's
  /// [BaseFailure].
  Future<Result<Asset, BaseFailure>> call(Asset asset) {
    return _repository.update(asset);
  }
}
