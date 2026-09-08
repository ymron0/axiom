import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/assets/domain/repositories/asset_repository.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_code.dart';

/// Retrieves all assets matching an asset code.
///
/// Example:
/// `final result = await GetAssetsByCodeUseCase(repository).call(code);`
class GetAssetsByCodeUseCase {
  /// Creates a use case backed by [repository].
  GetAssetsByCodeUseCase(this._repository);

  final AssetRepository _repository;

  /// Returns matching assets, or the repository's [BaseFailure].
  Future<Result<List<Asset>, BaseFailure>> call(AssetCode code) {
    return _repository.getByCode(code);
  }
}
