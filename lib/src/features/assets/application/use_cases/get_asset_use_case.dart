import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/assets/domain/repositories/asset_repository.dart';

/// Retrieves all assets from the asset repository.
///
/// Example: `final result = await GetAssetUseCase(repository).call();`
class GetAssetUseCase {
  /// Creates a use case backed by [repository].
  GetAssetUseCase(this._repository);

  final AssetRepository _repository;

  /// Returns every stored asset, or the repository's [BaseFailure].
  Future<Result<List<Asset>, BaseFailure>> call() {
    return _repository.getAll();
  }
}