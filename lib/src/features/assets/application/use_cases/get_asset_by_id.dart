import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/assets/domain/repositories/asset_repository.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';

/// Retrieves an asset by its identifier.
///
/// Example: `final result = await GetAssetByIdUseCase(repository).call(id);`
class GetAssetByIdUseCase {
  /// Creates a use case backed by [repository].
  GetAssetByIdUseCase(this._repository);

  final AssetRepository _repository;

  /// Returns the matching asset, `null` when it is absent, or a [BaseFailure].
  Future<Result<Asset?, BaseFailure>> call(AssetId id) {
    return _repository.getById(id);
  }
}
