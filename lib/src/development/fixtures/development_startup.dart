import 'package:axiom/src/core/di/database_storage_mode_provider.dart';
import 'package:axiom/src/core/persistence/database_storage_mode.dart';
import 'package:axiom/src/development/fixtures/di/reload_fixtures_service_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether persistent development data must be reset and fixtures reloaded.
///
/// Enable with:
///
/// ```text
/// --dart-define=RELOAD_FIXTURES=true
/// ```
///
/// In-memory databases always load fixtures because they start empty on every
/// application run.
const bool _reloadFixtures = bool.fromEnvironment(
  'RELOAD_FIXTURES',
  defaultValue: false,
);

/// Executes development-only startup operations.
///
/// In-memory storage always loads fixtures.
///
/// Persistent storage loads fixtures only when `RELOAD_FIXTURES=true`.
Future<void> runDevelopmentStartupTasks(ProviderContainer container) async {
  final storageMode = container.read(databaseStorageModeProvider);

  final shouldLoadFixtures = switch (storageMode) {
    DatabaseStorageMode.memory => true,
    DatabaseStorageMode.persistent => _reloadFixtures,
  };

  if (!shouldLoadFixtures) {
    return;
  }

  await container.read(reloadFixturesServiceProvider)();
}
