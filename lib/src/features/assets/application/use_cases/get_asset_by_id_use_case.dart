import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/assets/domain/failures/asset_failure.dart';
import 'package:axiom/src/features/assets/domain/repositories/asset_repository.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';

/// Retrieves an asset by its identifier.
///
/// Example: `final result = await GetAssetByIdUseCase(repository).call(id);`
class GetAssetByIdUseCase {
  /// Creates a use case backed by [repository].
  GetAssetByIdUseCase(this._repository);

  final AssetRepository _repository;

  /// Returns the matching asset, `null` when it is absent, or an [AssetFailure].
  Future<Result<Asset?, AssetFailure>> call(AssetId id) {
    return _repository.getById(id);
  }
}
