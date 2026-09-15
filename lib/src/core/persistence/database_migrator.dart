import 'package:sembast/sembast.dart';

import 'unsupported_database_version_exception.dart';

/// Performs one migration step for a Sembast [Database].
typedef DatabaseMigration = Future<void> Function(Database database);

/// Applies persistent database schema migrations.
///
/// Sembast invokes [migrate] whenever the version stored in the database
/// differs from the version requested while opening it.
///
/// Migrations are cumulative. A database upgrading across multiple versions
/// must execute every intermediate migration in ascending order.
///
/// Released migration steps must never be rewritten. When persisted structure
/// changes again, increment `DatabaseSchema.version` and add another migration
/// step instead.
///
/// Sembast runs the version-change callback inside its opening transaction.
/// Migration methods therefore must not start a second nested database
/// transaction.
final class DatabaseMigrator {
  final List<DatabaseMigration> _migrations;

  /// Creates a database migrator.
  ///
  /// [migrations] is ordered by target schema version, starting at version
  /// 1. The default contains the application's current migration steps.
  const DatabaseMigrator({
    List<DatabaseMigration> migrations = const [_migrateToVersion1],
  }) : _migrations = // ignore: prefer_initializing_formals
           migrations;

  /// Migrates [database] from [oldVersion] to [newVersion].
  ///
  /// Sembast reports version `0` for a newly created database.
  ///
  /// Downgrades are deliberately rejected. Opening a database created by a
  /// newer version of the application with older persistence code could cause
  /// data loss or incorrectly interpret persisted records.
  ///
  /// Throws [UnsupportedDatabaseVersionException] when [oldVersion] is newer
  /// than [newVersion].
  Future<void> migrate(
    Database database,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion > newVersion) {
      throw UnsupportedDatabaseVersionException(
        existingVersion: oldVersion,
        supportedVersion: newVersion,
      );
    }

    for (
      var version = 1;
      version <= newVersion && version <= _migrations.length;
      version++
    ) {
      if (oldVersion < version) {
        await _migrations[version - 1](database);
      }
    }
  }

  /// Initializes schema version 1.
  ///
  /// No explicit store creation is required because Sembast stores are
  /// created lazily when records are first written.
  static Future<void> _migrateToVersion1(Database database) {
    return Future<void>.value();
  }
}
