import 'package:axiom/src/features/assets/di/asset_repository_provider.dart';
import 'package:axiom/src/features/assets/application/use_cases/update_all_assets_use_case.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'update_all_assets_use_case_provider.g.dart';

/// Provides the use case for updating multiple assets.
@riverpod
UpdateAllAssetsUseCase updateAllAssetsUseCase(Ref ref) {
  return UpdateAllAssetsUseCase(ref.watch(assetRepositoryProvider));
}
