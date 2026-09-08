import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/assets/domain/repositories/asset_repository.dart';

/// Creates and stores multiple assets through the asset repository.
///
/// Example:
/// `final result = await CreateAssetsUseCase(repository).call(assets);`
class CreateAssetsUseCase {
  /// Creates a use case backed by [repository].
  CreateAssetsUseCase(this._repository);

  final AssetRepository _repository;

  /// Stores [assets] and returns them, or the repository's [BaseFailure].
  Future<Result<List<Asset>, BaseFailure>> call(List<Asset> assets) {
    return _repository.createAll(assets);
  }
}
