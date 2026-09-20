import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/application/failures/asset_type_change_not_allowed_failure.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/assets/domain/failures/asset_failure.dart';
import 'package:axiom/src/features/assets/domain/failures/asset_not_found_failure.dart';
import 'package:axiom/src/features/assets/domain/repositories/asset_repository.dart';

/// Replaces one stored asset while preserving its concrete asset type.
///
/// Mutable metadata may change, and CryptoAsset payment eligibility may change,
/// but the identity may not be reused for a different Asset subtype.
final class UpdateAssetUseCase {
  final AssetRepository _repository;

  /// Creates a use case backed by [repository].
  const UpdateAssetUseCase(this._repository);

  /// Validates subtype identity and persists [asset].
  Future<Result<Asset, AssetFailure>> call(Asset asset) async {
    final existingResult = await _repository.getById(asset.id);

    return existingResult.when<Future<Result<Asset, AssetFailure>>>(
      success: (existing) async {
        if (existing == null) {
          return AssetNotFoundFailure(
            message: 'Asset ID was not found: ${asset.id.value}',
          );
        }

        if (!_hasSameConcreteType(existing, asset)) {
          return AssetTypeChangeNotAllowedFailure(
            message:
                'Asset ${asset.id.value} cannot change from '
                '${existing.runtimeType} to ${asset.runtimeType}.',
          );
        }

        return _repository.update(asset);
      },
      failure: (failure) async => failure,
    );
  }

  bool _hasSameConcreteType(Asset left, Asset right) {
    return switch ((left, right)) {
      (Currency(), Currency()) => true,
      (CryptoAsset(), CryptoAsset()) => true,
      (StockAsset(), StockAsset()) => true,
      (CommodityAsset(), CommodityAsset()) => true,
      _ => false,
    };
  }
}
