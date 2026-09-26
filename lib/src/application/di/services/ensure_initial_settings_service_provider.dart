import 'package:axiom/src/application/di/services/initialize_settings_service_provider.dart';
import 'package:axiom/src/application/services/ensure_initial_settings_service.dart';
import 'package:axiom/src/features/settings/di/get_settings_use_case_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'ensure_initial_settings_service_provider.g.dart';

/// Provides idempotent initial Settings creation.
@riverpod
EnsureInitialSettingsService ensureInitialSettingsService(Ref ref) {
  return EnsureInitialSettingsService(
    getSettings: ref.watch(getSettingsUseCaseProvider),
    initializeSettings: ref.watch(initializeSettingsServiceProvider),
  );
}
