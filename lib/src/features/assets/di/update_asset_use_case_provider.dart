import 'package:axiom/src/features/assets/di/asset_repository_provider.dart';
import 'package:axiom/src/features/assets/application/use_cases/update_asset_use_case.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'update_asset_use_case_provider.g.dart';

/// Provides the use case for updating one asset.
@riverpod
UpdateAssetUseCase updateAssetUseCase(Ref ref) {
  return UpdateAssetUseCase(ref.watch(assetRepositoryProvider));
}
