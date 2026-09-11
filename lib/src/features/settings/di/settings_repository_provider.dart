import 'package:axiom/src/features/settings/data/repositories/in_memory_settings_repository_impl.dart';
import 'package:axiom/src/features/settings/domain/repositories/settings_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'settings_repository_provider.g.dart';

/// Provides the repository used by the settings feature.
@riverpod
SettingsRepository settingsRepository(Ref ref) {
  return InMemorySettingsRepositoryImpl();
}
