import 'package:axiom/src/features/assets/di/asset_repository_provider.dart';
import 'package:axiom/src/features/assets/application/use_cases/get_assets_by_ids_use_case.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'get_assets_by_ids_use_case_provider.g.dart';

/// Provides the use case for retrieving assets by identifiers.
@riverpod
GetAssetsByIdsUseCase getAssetsByIdsUseCase(Ref ref) {
  return GetAssetsByIdsUseCase(ref.watch(assetRepositoryProvider));
}
