import 'package:sembast/sembast.dart';

/// Applies database schema migrations.
///
/// Every schema migration must be additive to this class. Existing migration
/// steps must not be modified once released because databases can be upgraded
/// from any earlier supported version.
final class DatabaseMigrator {
  const DatabaseMigrator();

  /// Migrates [database] from [oldVersion] to [newVersion].
  ///
  /// Sembast reports version `0` for a newly created database, so a new
  /// database opened with schema version `1` also passes through the version
  /// 1 migration.
  Future<void> migrate(
    Database database,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 1 && newVersion >= 1) {
      await _migrateToVersion1(database);
    }
  }

  /// Initializes schema version 1.
  ///
  /// No explicit store creation is required because Sembast creates stores
  /// lazily when data is first written.
  Future<void> _migrateToVersion1(Database database) {
    return Future<void>.value();
  }
}
