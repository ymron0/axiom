import 'package:axiom/src/application/bootstrap/resolve_database_storage_mode.dart';
import 'package:axiom/src/core/di/database_root_path_provider.dart';
import 'package:axiom/src/core/di/database_storage_mode_provider.dart';
import 'package:axiom/src/core/persistence/database_storage_mode.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

const String _databaseStorageMode = String.fromEnvironment(
  'DATABASE_STORAGE',
  defaultValue: 'persistent',
);

/// Resolves Riverpod [Override]s required for database configuration.
///
/// Determines the [DatabaseStorageMode] from the environment and build mode,
/// then prepends the corresponding [databaseStorageModeProvider] and optional
/// [databaseRootPathProvider] overrides to the given [overrides].
///
/// When persistent storage is selected, the database root path is resolved from
/// the application documents directory.
///
/// Throws an [ArgumentError] if the configured storage mode is neither
/// `'persistent'` nor `'memory'`.
///
/// Throws a [StateError] if an in-memory database is requested in a release
/// build.
Future<List<Override>> resolveDatabaseOverrides({
  required List<Override> overrides,
}) async {
  final storageMode = resolveDatabaseStorageMode(
    databaseStorageMode: _databaseStorageMode,
    isReleaseMode: kReleaseMode,
    resolvePersistentDatabaseRootPath: () async {
      final directory = await getApplicationDocumentsDirectory();
      return directory.path;
    },
  );

  if (storageMode == DatabaseStorageMode.memory) {
    return [
      databaseStorageModeProvider.overrideWithValue(DatabaseStorageMode.memory),
      ...overrides,
    ];
  }

  final documentsDirectory = await getApplicationDocumentsDirectory();

  return [
    databaseStorageModeProvider.overrideWithValue(
      DatabaseStorageMode.persistent,
    ),
    databaseRootPathProvider.overrideWithValue(documentsDirectory.path),
    ...overrides,
  ];
}
