import 'package:axiom/src/core/di/validated_database_provider.dart';
import 'package:axiom/src/features/settings/data/repositories/sembast_settings_repository_impl.dart';
import 'package:axiom/src/features/settings/domain/repositories/settings_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'settings_repository_provider.g.dart';

/// Provides the persistent repository used by the settings feature.
///
/// The database must already have completed the validated persistence
/// lifecycle before this provider is resolved.
@Riverpod(keepAlive: true)
SettingsRepository settingsRepository(Ref ref) {
  return SembastSettingsRepositoryImpl(
    database: ref.watch(validatedDatabaseProvider),
  );
}
