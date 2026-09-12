import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/failures/record_not_found_failure.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/application/use_cases/get_asset_by_id_use_case.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/settings/application/use_cases/get_settings_use_case.dart';

/// Resolves the asset configured as the application's valuation asset.
///
/// This service coordinates the Settings and Assets features:
///
/// 1. Loads the current settings.
/// 2. Reads the configured valuation asset ID.
/// 3. Resolves that ID to its corresponding [Asset].
///
/// A [RecordNotFoundFailure] is returned when settings have not yet been
/// initialized or when the configured valuation asset no longer exists.
final class GetValuationAssetService {
  /// Creates a valuation asset service.
  const GetValuationAssetService({
    required GetSettingsUseCase getSettings,
    required GetAssetByIdUseCase getAssetById,
  }) : _getSettings = getSettings, // ignore: prefer_initializing_formals
       _getAssetById = getAssetById; // ignore: prefer_initializing_formals

  final GetSettingsUseCase _getSettings;
  final GetAssetByIdUseCase _getAssetById;

  /// Returns the asset configured as the valuation asset.
  Future<Result<Asset, BaseFailure>> call() async {
    final settingsResult = await _getSettings();

    return settingsResult.when<Future<Result<Asset, BaseFailure>>>(
      success: (settings) async {
        if (settings == null) {
          return RecordNotFoundFailure(
            message: 'Settings have not been initialized.',
          );
        }

        final assetResult = await _getAssetById(settings.valuationCurrencyId);

        return assetResult.when<Result<Asset, BaseFailure>>(
          success: (asset) {
            if (asset == null) {
              return RecordNotFoundFailure(
                message:
                    'Valuation asset with ID '
                    '"${settings.valuationCurrencyId.value}" was not found.',
              );
            }

            return Success(asset);
          },
          failure: (failure) => failure,
        );
      },
      failure: (failure) async => failure,
    );
  }
}
