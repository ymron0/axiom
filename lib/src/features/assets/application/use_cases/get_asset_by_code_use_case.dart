import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/assets/domain/failures/asset_failure.dart';
import 'package:axiom/src/features/assets/domain/repositories/asset_repository.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_code.dart';

/// Retrieves the asset matching an asset code.
///
/// Example:
/// `final result = await GetAssetByCodeUseCase(repository).call(code);`
class GetAssetByCodeUseCase {
  /// Creates a use case backed by [repository].
  GetAssetByCodeUseCase(this._repository);

  final AssetRepository _repository;

  /// Returns the matching asset, `null` when absent, or an [AssetFailure].
  Future<Result<Asset?, AssetFailure>> call(AssetCode code) {
    return _repository.getByCode(code);
  }
}
