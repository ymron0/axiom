import 'package:axiom/src/features/assets/di/get_assets_by_ids_use_case_provider.dart';
import 'package:axiom/src/features/rates/application/services/create_rate_service.dart';
import 'package:axiom/src/features/rates/application/services/validate_rate_assets_service.dart';
import 'package:axiom/src/features/rates/di/canonical_bridge_asset_id_provider.dart';
import 'package:axiom/src/features/rates/di/rate_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'create_rate_service_provider.g.dart';

/// Provides the shared service for validating and persisting rates.
@riverpod
CreateRateService createRateService(Ref ref) {
  return CreateRateService(
    repository: ref.watch(rateRepositoryProvider),
    validateRateAssets: ValidateRateAssetsService(
      getAssetsByIds: ref.watch(getAssetsByIdsUseCaseProvider),
    ),
    canonicalBridgeAssetId: ref.watch(canonicalBridgeAssetIdProvider),
  );
}
