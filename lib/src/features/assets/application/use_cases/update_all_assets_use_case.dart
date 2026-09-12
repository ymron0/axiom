import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/assets/domain/failures/asset_failure.dart';
import 'package:axiom/src/features/assets/domain/repositories/asset_repository.dart';

/// Updates multiple stored assets through the asset repository.
///
/// Example:
/// `final result = await UpdateAllAssetsUseCase(repository).call(assets);`
class UpdateAllAssetsUseCase {
  /// Creates a use case backed by [repository].
  UpdateAllAssetsUseCase(this._repository);

  final AssetRepository _repository;

  /// Replaces the stored assets and returns them, or the repository's
  /// [AssetFailure].
  Future<Result<List<Asset>, AssetFailure>> call(List<Asset> assets) {
    return _repository.updateAll(assets);
  }
}
