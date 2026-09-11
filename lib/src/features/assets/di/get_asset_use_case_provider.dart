import 'package:axiom/src/features/assets/di/asset_repository_provider.dart';
import 'package:axiom/src/features/assets/application/use_cases/get_asset_use_case.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'get_asset_use_case_provider.g.dart';

/// Provides the use case for retrieving all assets.
@riverpod
GetAssetUseCase getAssetUseCase(Ref ref) {
  return GetAssetUseCase(ref.watch(assetRepositoryProvider));
}
