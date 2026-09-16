import 'package:axiom/src/core/persistence/database_storage_mode.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'database_storage_mode_provider.g.dart';

/// Provides the storage strategy used by the application's database.
///
/// Production defaults to persistent storage.
///
/// Application bootstrap may override this provider when a different
/// persistence strategy is required.
@Riverpod(keepAlive: true)
DatabaseStorageMode databaseStorageMode(Ref ref) {
  return DatabaseStorageMode.persistent;
}
