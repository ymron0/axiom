import 'package:axiom/src/features/assets/di/get_asset_by_code_use_case_provider.dart';
import 'package:axiom/src/features/assets/di/get_assets_by_ids_use_case_provider.dart';
import 'package:axiom/src/features/rates/application/services/validate_rate_assets_service.dart';
import 'package:axiom/src/features/rates/application/use_cases/get_rate_for_pair_use_case.dart';
import 'package:axiom/src/features/rates/di/rate_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'get_rate_for_pair_use_case_provider.g.dart';

/// Provides the use case for retrieving rates for an exact asset pair.
@riverpod
GetRateForPairUseCase getRateForPairUseCase(Ref ref) {
  return GetRateForPairUseCase(
    repository: ref.watch(rateRepositoryProvider),
    getAssetByCode: ref.watch(getAssetByCodeUseCaseProvider),
    validateRateAssets: ValidateRateAssetsService(
      getAssetsByIds: ref.watch(getAssetsByIdsUseCaseProvider),
    ),
  );
}
