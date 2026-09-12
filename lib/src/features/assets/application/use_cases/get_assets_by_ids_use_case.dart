import 'package:axiom/src/core/repositories/batch_lookup.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/assets/domain/failures/asset_failure.dart';
import 'package:axiom/src/features/assets/domain/repositories/asset_repository.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';

/// Retrieves assets matching a list of identifiers.
///
/// Example:
/// `final result = await GetAssetsByIdsUseCase(repository).call(assetIds);`
class GetAssetsByIdsUseCase {
  /// Creates a use case backed by [repository].
  GetAssetsByIdsUseCase(this._repository);

  final AssetRepository _repository;

  /// Returns found assets and missing identifiers, or an [AssetFailure].
  Future<Result<BatchLookup<Asset, AssetId>, AssetFailure>> call(
    List<AssetId> ids,
  ) {
    return _repository.getByIds(ids);
  }
}
