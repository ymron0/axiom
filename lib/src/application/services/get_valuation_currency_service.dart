import 'package:axiom/src/application/failures/invalid_valuation_currency_failure.dart';
import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/application/use_cases/get_asset_by_id_use_case.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/assets/domain/failures/asset_not_found_failure.dart';
import 'package:axiom/src/features/settings/application/use_cases/get_settings_use_case.dart';
import 'package:axiom/src/features/settings/domain/failures/settings_not_initialized_failure.dart';

/// Resolves and validates the configured valuation currency.
///
/// Unlike a generic asset lookup, this service guarantees that a successful
/// result is a concrete [Currency].
///
/// Crypto assets remain invalid here even when they are payment enabled.
final class GetValuationCurrencyService {
  final GetSettingsUseCase _getSettings;

  final GetAssetByIdUseCase _getAssetById;
  /// Creates the service.
  const GetValuationCurrencyService({
    required GetSettingsUseCase getSettings,
    required GetAssetByIdUseCase getAssetById,
  }) : _getSettings = getSettings, // ignore: prefer_initializing_formals
       _getAssetById = getAssetById; // ignore: prefer_initializing_formals

  /// Returns the configured valuation [Currency].
  Future<Result<Currency, BaseFailure>> call() async {
    final settingsResult = await _getSettings();

    if (settingsResult case final Failure<BaseFailure> failure) {
      return failure;
    }

    final settings = settingsResult.valueOrNull;

    if (settings == null) {
      return const SettingsNotInitializedFailure(
        message: 'Settings have not been initialized.',
      );
    }

    final assetResult = await _getAssetById(settings.valuationCurrencyId);

    return assetResult.when<Result<Currency, BaseFailure>>(
      success: (asset) {
        if (asset == null) {
          return AssetNotFoundFailure(
            message:
                'Valuation currency was not found: '
                '${settings.valuationCurrencyId.value}',
          );
        }

        if (asset is! Currency) {
          return InvalidValuationCurrencyFailure(
            message:
                'Configured valuation asset '
                '${asset.id.value} is not a Currency.',
          );
        }

        return Success(asset);
      },
      failure: (failure) => failure,
    );
  }
}
