import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/application/failures/asset_type_change_not_allowed_failure.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/assets/domain/failures/asset_failure.dart';
import 'package:axiom/src/features/assets/domain/failures/asset_not_found_failure.dart';
import 'package:axiom/src/features/assets/domain/repositories/asset_repository.dart';

/// Atomically updates multiple assets while preserving their concrete types.
final class UpdateAllAssetsUseCase {
  final AssetRepository _repository;

  /// Creates a use case backed by [repository].
  const UpdateAllAssetsUseCase(this._repository);

  /// Validates every existing subtype before performing the atomic update.
  Future<Result<List<Asset>, AssetFailure>> call(List<Asset> assets) async {
    if (assets.isEmpty) {
      return _repository.updateAll(assets);
    }

    final lookupResult = await _repository.getByIds(
      assets.map((asset) => asset.id).toList(growable: false),
    );

    return lookupResult.when<Future<Result<List<Asset>, AssetFailure>>>(
      success: (lookup) async {
        if (lookup.missing.isNotEmpty) {
          return AssetNotFoundFailure(
            message:
                'Asset ID was not found: '
                '${lookup.missing.first.value}',
          );
        }

        final existingById = {
          for (final asset in lookup.found) asset.id: asset,
        };

        for (final updated in assets) {
          final existing = existingById[updated.id];

          if (existing == null) {
            return AssetNotFoundFailure(
              message: 'Asset ID was not found: ${updated.id.value}',
            );
          }

          if (!_hasSameConcreteType(existing, updated)) {
            return AssetTypeChangeNotAllowedFailure(
              message:
                  'Asset ${updated.id.value} cannot change from '
                  '${existing.runtimeType} to ${updated.runtimeType}.',
            );
          }
        }

        return _repository.updateAll(assets);
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
