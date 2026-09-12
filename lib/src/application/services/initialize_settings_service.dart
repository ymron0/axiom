import 'package:axiom/src/application/failures/invalid_valuation_currency_failure.dart';
import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/failures/record_not_found_failure.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/application/use_cases/get_asset_by_id_use_case.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/settings/application/use_cases/create_settings_use_case.dart';
import 'package:axiom/src/features/settings/domain/entities/settings.dart';

/// Initializes application settings.
///
/// This service coordinates the Assets and Settings features during initial
/// application setup.
///
/// The selected valuation asset must exist and must represent a [Currency].
/// After validation, the service constructs the initial [Settings] and
/// delegates persistence to [CreateSettingsUseCase].
///
/// ## Invariants
///
/// - The valuation asset must exist.
/// - The valuation asset must be a [Currency].
/// - Settings creation is delegated to [CreateSettingsUseCase].
/// - This service does not access feature repositories directly.
///
/// ## Semantics
///
/// Initialization is a cross-feature operation because determining whether an
/// [AssetId] is suitable as the valuation currency requires information owned
/// by the Assets feature.
///
/// Once the asset has been validated, the Settings feature receives only the
/// valid [AssetId] and does not depend on the Assets feature.
///
/// ## Contract
///
/// Returns:
///
/// - the created [Settings] on success;
/// - the failure returned while retrieving the asset;
/// - [InvalidValuationCurrencyFailure] when the selected asset exists but is
///   not a currency;
/// - the failure returned while creating settings.
final class InitializeSettingsService {
  /// Creates an initialization service.
  const InitializeSettingsService({
    required GetAssetByIdUseCase getAssetById,
    required CreateSettingsUseCase createSettings,
  }) : _getAssetById = getAssetById, // ignore: prefer_initializing_formals
       _createSettings = createSettings; // ignore: prefer_initializing_formals

  final GetAssetByIdUseCase _getAssetById;
  final CreateSettingsUseCase _createSettings;

  /// Initializes settings using [valuationAssetId] as the valuation currency.
  Future<Result<Settings, BaseFailure>> call({
    required AssetId valuationAssetId,
  }) async {
    final assetResult = await _getAssetById(valuationAssetId);

    return assetResult.when<Future<Result<Settings, BaseFailure>>>(
      success: (asset) async {
        if (asset == null) {
          return RecordNotFoundFailure(
            message: 'Valuation asset was not found: $valuationAssetId',
          );
        }

        if (asset is! Currency) {
          return InvalidValuationCurrencyFailure(
            message: 'Invalid valuation currency: $valuationAssetId',
          );
        }

        final settings = Settings(valuationCurrencyId: valuationAssetId);
        return _createSettings(settings);
      },
      failure: (failure) async => failure,
    );
  }
}
