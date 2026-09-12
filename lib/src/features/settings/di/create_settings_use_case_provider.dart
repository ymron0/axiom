import 'package:axiom/src/features/settings/application/use_cases/create_settings_use_case.dart';
import 'package:axiom/src/features/settings/di/settings_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'create_settings_use_case_provider.g.dart';

/// Provides the use case for creating the application's initial settings.
@riverpod
CreateSettingsUseCase createSettingsUseCase(Ref ref) {
  return CreateSettingsUseCase(ref.watch(settingsRepositoryProvider));
}
