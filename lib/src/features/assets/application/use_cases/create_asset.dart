import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/assets/domain/repositories/asset_repository.dart';

/// Creates and stores one asset through the asset repository.
///
/// Example: `final result = await CreateAssetUseCase(repository).call(asset);`
class CreateAssetUseCase {
  /// Creates a use case backed by [repository].
  CreateAssetUseCase(this._repository);

  final AssetRepository _repository;

  /// Stores [asset] and returns it, or the repository's [BaseFailure].
  Future<Result<Asset, BaseFailure>> call(Asset asset) {
    return _repository.create(asset);
  }
}
