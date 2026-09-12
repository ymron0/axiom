import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/assets/domain/failures/asset_failure.dart';
import 'package:axiom/src/features/assets/domain/repositories/asset_repository.dart';

/// Creates and stores multiple assets through the asset repository.
///
/// Example:
/// `final result = await CreateAllAssetsUseCase(repository).call(assets);`
class CreateAllAssetsUseCase {
  /// Creates a use case backed by [repository].
  CreateAllAssetsUseCase(this._repository);

  final AssetRepository _repository;

  /// Stores [assets] and returns them, or an [AssetFailure].
  Future<Result<List<Asset>, AssetFailure>> call(List<Asset> assets) {
    return _repository.createAll(assets);
  }
}