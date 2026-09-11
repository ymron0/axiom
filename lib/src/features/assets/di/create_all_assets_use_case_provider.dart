import 'package:axiom/src/features/assets/application/use_cases/create_all_assets_use_case.dart';
import 'package:axiom/src/features/assets/di/asset_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'create_all_assets_use_case_provider.g.dart';

/// Provides the use case for creating multiple assets.
@riverpod
CreateAllAssetsUseCase createAllAssetsUseCase(Ref ref) {
  return CreateAllAssetsUseCase(ref.watch(assetRepositoryProvider));
}
