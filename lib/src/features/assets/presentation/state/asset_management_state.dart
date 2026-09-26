import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/di/get_asset_use_case_provider.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/assets/domain/failures/asset_failure.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'asset_management_state.g.dart';

/// Loads all assets for management.
///
/// Ordering is deterministic by asset type and then canonical asset code.
@riverpod
Future<Result<List<Asset>, AssetFailure>> managedAssets(Ref ref) async {
  final result = await ref.watch(getAssetUseCaseProvider)();

  return result.when<Result<List<Asset>, AssetFailure>>(
    success: (assets) {
      final sorted = List<Asset>.of(assets)
        ..sort((left, right) {
          final typeOrder = _assetTypeRank(
            left,
          ).compareTo(_assetTypeRank(right));

          if (typeOrder != 0) {
            return typeOrder;
          }

          return left.code.value.compareTo(right.code.value);
        });

      return Success(List.unmodifiable(sorted));
    },
    failure: (failure) => failure,
  );
}

int _assetTypeRank(Asset asset) {
  return switch (asset) {
    Currency() => 0,
    CryptoAsset() => 1,
    StockAsset() => 2,
    CommodityAsset() => 3,
  };
}
