import 'package:axiom/src/application/services/initialize_settings_service.dart';
import 'package:axiom/src/features/assets/di/get_asset_by_id_use_case_provider.dart';
import 'package:axiom/src/features/settings/di/create_settings_use_case_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'initialize_settings_service_provider.g.dart';

/// Provides the service that initializes application settings.
@riverpod
InitializeSettingsService initializeSettingsService(Ref ref) {
  return InitializeSettingsService(
    getAssetById: ref.watch(getAssetByIdUseCaseProvider),
    createSettings: ref.watch(createSettingsUseCaseProvider),
  );
}
