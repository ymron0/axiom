import 'package:axiom/src/features/assets/di/asset_repository_provider.dart';
import 'package:axiom/src/features/assets/application/use_cases/get_asset_by_id_use_case.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'get_asset_by_id_use_case_provider.g.dart';

/// Provides the use case for retrieving an asset by identifier.
@riverpod
GetAssetByIdUseCase getAssetByIdUseCase(Ref ref) {
  return GetAssetByIdUseCase(ref.watch(assetRepositoryProvider));
}
