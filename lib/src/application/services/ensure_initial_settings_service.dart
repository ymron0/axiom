import 'package:axiom/src/application/services/initialize_settings_service.dart';
import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/settings/application/use_cases/get_settings_use_case.dart';
import 'package:axiom/src/features/settings/domain/entities/settings.dart';
import 'package:axiom/src/features/settings/domain/failures/settings_valuation_currency_change_not_allowed_failure.dart';

/// Ensures initial Settings exist for onboarding.
///
/// ## Semantics
///
/// The operation is idempotent for the same valuation currency.
///
/// If Settings already exist with the requested currency, the existing
/// Settings are returned unchanged. This allows an interrupted onboarding flow
/// to resume safely.
///
/// An existing different valuation currency cannot be replaced because the
/// valuation currency is immutable after initialization.
///
/// ## Contract
///
/// Concrete failures are returned directly as Result failures.
final class EnsureInitialSettingsService {
  /// Creates the service.
  const EnsureInitialSettingsService({
    required GetSettingsUseCase getSettings,
    required InitializeSettingsService initializeSettings,
  }) : _getSettings = getSettings, // ignore: prefer_initializing_formals
       _initializeSettings = // ignore: prefer_initializing_formals
           initializeSettings;

  final GetSettingsUseCase _getSettings;
  final InitializeSettingsService _initializeSettings;

  /// Ensures Settings exist using [valuationCurrencyId].
  Future<Result<Settings, BaseFailure>> call({
    required AssetId valuationCurrencyId,
  }) async {
    final existingResult = await _getSettings();

    if (existingResult case final Failure<BaseFailure> failure) {
      return failure;
    }

    final existing = existingResult.valueOrNull;

    if (existing == null) {
      return _initializeSettings(valuationAssetId: valuationCurrencyId);
    }

    if (existing.valuationCurrencyId != valuationCurrencyId) {
      return const SettingsValuationCurrencyChangeNotAllowedFailure(
        message:
            'A different valuation currency has already been initialized. '
            'Reset the application to choose another valuation currency.',
      );
    }

    return Success(existing);
  }
}
