import 'package:axiom/src/features/settings/application/use_cases/update_settings_use_case.dart';
import 'package:axiom/src/features/settings/di/settings_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'update_settings_use_case_provider.g.dart';

/// Provides the use case for updating application settings.
@riverpod
UpdateSettingsUseCase updateSettingsUseCase(Ref ref) {
  return UpdateSettingsUseCase(ref.watch(settingsRepositoryProvider));
}
