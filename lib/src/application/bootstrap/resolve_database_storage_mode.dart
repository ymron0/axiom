import 'package:axiom/src/core/persistence/database_storage_mode.dart';

/// Resolves the [DatabaseStorageMode] for the application.
///
/// Parses [databaseStorageMode] into a [DatabaseStorageMode], accepting
/// case-insensitive `'persistent'` and `'memory'` values.
///
/// The [resolvePersistentDatabaseRootPath] callback supplies the directory path
/// resolver for persistent storage.
///
/// Throws an [ArgumentError] if [databaseStorageMode] is neither `'persistent'`
/// nor `'memory'`.
///
/// Throws a [StateError] if [isReleaseMode] is `true` and the resolved mode is
/// [DatabaseStorageMode.memory].
DatabaseStorageMode resolveDatabaseStorageMode({
  required String databaseStorageMode,
  required bool isReleaseMode,
  required Future<String> Function() resolvePersistentDatabaseRootPath,
}) {
  final storageMode = switch (databaseStorageMode.trim().toLowerCase()) {
    'persistent' => DatabaseStorageMode.persistent,
    'memory' => DatabaseStorageMode.memory,
    _ => throw ArgumentError.value(
      databaseStorageMode,
      'DATABASE_STORAGE',
      'Expected "persistent" or "memory".',
    ),
  };

  if (isReleaseMode && storageMode == DatabaseStorageMode.memory) {
    throw StateError(
      'In-memory database storage is not allowed in release builds.',
    );
  }

  return storageMode;
}
