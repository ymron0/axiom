import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/assets/domain/repositories/asset_repository.dart';

/// Updates multiple stored assets through the asset repository.
///
/// Example:
/// `final result = await UpdateAssetsUseCase(repository).call(assets);`
class UpdateAssetsUseCase {
  /// Creates a use case backed by [repository].
  UpdateAssetsUseCase(this._repository);

  final AssetRepository _repository;

  /// Replaces the stored assets and returns them, or the repository's
  /// [BaseFailure].
  Future<Result<List<Asset>, BaseFailure>> call(List<Asset> assets) {
    return _repository.updateAll(assets);
  }
}
