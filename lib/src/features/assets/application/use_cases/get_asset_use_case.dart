import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/assets/domain/failures/asset_failure.dart';
import 'package:axiom/src/features/assets/domain/repositories/asset_repository.dart';

/// Retrieves all assets from the asset repository.
///
/// Example: `final result = await GetAssetUseCase(repository).call();`
class GetAssetUseCase {
  /// Creates a use case backed by [repository].
  GetAssetUseCase(this._repository);

  final AssetRepository _repository;

  /// Returns every stored asset, or an [AssetFailure].
  Future<Result<List<Asset>, AssetFailure>> call() {
    return _repository.getAll();
  }
}
