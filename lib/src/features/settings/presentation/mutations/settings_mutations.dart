import 'package:axiom/src/application/di/services/initialize_settings_service_provider.dart';
import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/settings/di/update_settings_use_case_provider.dart';
import 'package:axiom/src/features/settings/domain/entities/settings.dart';
import 'package:flutter_riverpod/experimental/mutation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/settings_state.dart';

final initializeSettingsMutation = Mutation<Result<Settings, BaseFailure>>(
  label: 'initialize-settings',
);

final updateSettingsMutation = Mutation<Result<Settings, BaseFailure>>(
  label: 'update-settings',
);

/// Initializes settings with the selected valuation currency.
///
/// [InitializeSettingsService] performs the authoritative asset lookup and
/// validates that [valuationCurrencyId] identifies a Currency.
Future<Result<Settings, BaseFailure>> executeInitializeSettings(
  WidgetRef ref,
  AssetId valuationCurrencyId,
) {
  return initializeSettingsMutation.run(ref, (transaction) async {
    final service = transaction.get(initializeSettingsServiceProvider);

    final result = await service(valuationAssetId: valuationCurrencyId);

    if (result.isSuccess) {
      ref.invalidate(settingsScreenDataProvider);
    }

    return result;
  });
}

/// Persists mutable settings.
///
/// The repository continues to enforce valuation-currency immutability.
Future<Result<Settings, BaseFailure>> executeUpdateSettings(
  WidgetRef ref,
  Settings settings,
) {
  return updateSettingsMutation.run(ref, (transaction) async {
    final useCase = transaction.get(updateSettingsUseCaseProvider);

    final result = await useCase(settings);

    if (result.isSuccess) {
      ref.invalidate(settingsScreenDataProvider);
    }

    return result;
  });
}
