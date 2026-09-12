import 'package:axiom/src/features/assets/di/get_assets_by_ids_use_case_provider.dart';
import 'package:axiom/src/features/rates/application/services/validate_rate_assets_service.dart';
import 'package:axiom/src/features/rates/application/use_cases/get_rate_by_id_use_case.dart';
import 'package:axiom/src/features/rates/di/rate_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'get_rate_by_id_use_case_provider.g.dart';

/// Provides the use case for retrieving a rate by identifier.
@riverpod
GetRateByIdUseCase getRateByIdUseCase(Ref ref) {
  return GetRateByIdUseCase(
    repository: ref.watch(rateRepositoryProvider),
    validateRateAssets: ValidateRateAssetsService(
      getAssetsByIds: ref.watch(getAssetsByIdsUseCaseProvider),
    ),
  );
}
