import 'package:axiom/src/features/assets/di/asset_repository_provider.dart';
import 'package:axiom/src/features/assets/application/use_cases/create_asset_use_case.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'create_asset_use_case_provider.g.dart';

/// Provides the use case for creating one asset.
@riverpod
CreateAssetUseCase createAssetUseCase(Ref ref) {
  return CreateAssetUseCase(ref.watch(assetRepositoryProvider));
}
