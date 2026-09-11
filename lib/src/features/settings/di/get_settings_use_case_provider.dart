import 'package:axiom/src/features/settings/application/use_cases/get_settings_use_case.dart';
import 'package:axiom/src/features/settings/di/settings_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'get_settings_use_case_provider.g.dart';

/// Provides the use case for retrieving the current settings.
@riverpod
GetSettingsUseCase getSettingsUseCase(Ref ref) {
  return GetSettingsUseCase(ref.watch(settingsRepositoryProvider));
}
