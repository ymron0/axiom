import 'package:axiom/src/core/di/database_root_path_provider.dart';
import 'package:axiom/src/core/di/database_storage_mode_provider.dart';
import 'package:axiom/src/core/persistence/database_storage_mode.dart';
import 'package:axiom/src/core/persistence/sembast_database.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sembast_database_provider.g.dart';

/// Provides the application-scoped Sembast database infrastructure.
///
/// Resolving this provider constructs the database wrapper but does not open
/// the database.
///
/// The configured [DatabaseStorageMode] determines whether the database uses:
///
/// - persistent filesystem storage; or
/// - in-memory storage.
///
/// Database opening, integrity validation, shutdown, and recovery remain
/// explicit lifecycle operations rather than dependency-injection side
/// effects.
///
/// Repositories consume this database through normal persistence
/// infrastructure and remain unaware of the selected storage strategy.
@Riverpod(keepAlive: true)
SembastDatabase sembastDatabase(Ref ref) {
  final storageMode = ref.watch(databaseStorageModeProvider);

  return switch (storageMode) {
    DatabaseStorageMode.persistent => SembastDatabase.io(
      rootPath: ref.watch(databaseRootPathProvider),
    ),
    DatabaseStorageMode.memory => SembastDatabase.memory(),
  };
}