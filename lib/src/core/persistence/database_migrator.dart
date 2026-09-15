import 'dart:io';

import 'package:sembast/sembast.dart';

import 'database_schema.dart';
import 'mapping/persistence_record_exception.dart';
import 'migrations/database_migration.dart';
import 'migrations/database_migration_exception.dart';
import 'migrations/database_migrations.dart';
import 'unsupported_database_version_exception.dart';

/// Applies released persistent database schema migrations.
///
/// ## Migration history
///
/// Migration history begins with schema version 1.
///
/// Version 0 is reserved for Sembast's representation of a newly created
/// database and is not a released application schema.
///
/// Every released schema version after version 1 must therefore have exactly
/// one migration:
///
/// `1 -> 2`
///
/// `2 -> 3`
///
/// `3 -> 4`
///
/// and so on.
///
/// The migration registry is validated when this class is constructed so a
/// broken migration configuration fails before persisted data is modified.
///
/// ## Fresh databases
///
/// When [oldVersion] is 0, no historical migrations are executed.
///
/// A newly created database starts directly at the requested current schema.
/// Historical migrations exist only to transform data that was actually
/// persisted using an older released schema.
///
/// ## Atomicity
///
/// All migration steps required for one database upgrade run inside one
/// Sembast transaction.
///
/// If any step fails, the transaction is aborted and earlier writes from the
/// same upgrade are rolled back.
///
/// The database must never be left partially migrated.
///
/// ## Failure handling
///
/// Expected persistence and persisted-data problems are translated into
/// [DatabaseMigrationException].
///
/// Programmer errors such as [StateError], [ArgumentError], and type errors are
/// intentionally not caught. They must remain visible during development.
final class DatabaseMigrator {
  final int _supportedVersion;
  final List<DatabaseMigration> _migrations;

  /// Creates a database migrator.
  ///
  /// Production code uses [DatabaseSchema.version] and
  /// [DatabaseMigrations.all].
  ///
  /// [supportedVersion] and [migrations] are injectable so migration behavior
  /// can be tested without modifying the production schema registry.
  ///
  /// Throws [ArgumentError] when:
  ///
  /// - [supportedVersion] is less than 1;
  /// - the migration count does not match [supportedVersion];
  /// - migrations are not ordered contiguously from version 1;
  /// - a migration does not advance exactly one schema version.
  DatabaseMigrator({
    int supportedVersion = DatabaseSchema.version,
    List<DatabaseMigration>? migrations,
  }) : _supportedVersion = // ignore: prefer_initializing_formals
           supportedVersion,
       _migrations = List<DatabaseMigration>.unmodifiable(
         migrations ?? DatabaseMigrations.all,
       ) {
    _validateConfiguration();
  }

  /// Migrates [database] from [oldVersion] to [newVersion].
  ///
  /// Sembast supplies version 0 when creating a new database.
  ///
  /// A fresh database does not replay historical migrations.
  ///
  /// Existing databases execute every required intermediate migration in
  /// ascending order inside one transaction.
  ///
  /// Throws [UnsupportedDatabaseVersionException] when attempting to open a
  /// database whose version is newer than the requested application schema.
  ///
  /// Throws [DatabaseMigrationException] when the requested migration cannot
  /// be completed safely.
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

    if (oldVersion < 0) {
      throw DatabaseMigrationException(
        fromVersion: oldVersion,
        toVersion: newVersion,
        message: 'The existing database schema version is invalid.',
      );
    }

    if (newVersion < 1 || newVersion > _supportedVersion) {
      throw DatabaseMigrationException(
        fromVersion: oldVersion,
        toVersion: newVersion,
        message:
            'The requested database schema version is not supported by the '
            'configured migration history.',
      );
    }

    // Sembast uses 0 for a database that does not yet have a released schema.
    //
    // There is no existing application data to migrate. The database can begin
    // directly at the requested current schema version.
    if (oldVersion == 0) {
      return;
    }

    if (oldVersion == newVersion) {
      return;
    }

    final requiredMigrations = _migrations.sublist(
      oldVersion - 1,
      newVersion - 1,
    );

    try {
      await database.transaction((transaction) async {
        for (final migration in requiredMigrations) {
          await _runMigration(transaction, migration);
        }
      });
    } on DatabaseMigrationException {
      rethrow;
    } on FileSystemException {
      throw DatabaseMigrationException(
        fromVersion: oldVersion,
        toVersion: newVersion,
        message: 'The database migration transaction could not be persisted.',
      );
    } on DatabaseException {
      throw DatabaseMigrationException(
        fromVersion: oldVersion,
        toVersion: newVersion,
        message: 'The database migration transaction failed.',
      );
    }
  }

  /// Executes one migration step and translates expected migration problems.
  Future<void> _runMigration(
    Transaction transaction,
    DatabaseMigration migration,
  ) async {
    try {
      await migration.operation(transaction);
    } on DatabaseMigrationException {
      rethrow;
    } on PersistenceRecordException {
      throw DatabaseMigrationException(
        fromVersion: migration.fromVersion,
        toVersion: migration.toVersion,
        message:
            'Persisted data could not be interpreted during database '
            'migration.',
      );
    } on FormatException {
      throw DatabaseMigrationException(
        fromVersion: migration.fromVersion,
        toVersion: migration.toVersion,
        message:
            'Persisted data contained an invalid value during database '
            'migration.',
      );
    } on FileSystemException {
      throw DatabaseMigrationException(
        fromVersion: migration.fromVersion,
        toVersion: migration.toVersion,
        message:
            'The database could not be persisted during database migration.',
      );
    } on DatabaseException {
      throw DatabaseMigrationException(
        fromVersion: migration.fromVersion,
        toVersion: migration.toVersion,
        message: 'A database operation failed during database migration.',
      );
    }
  }

  /// Validates the complete migration registry before it can be used.
  void _validateConfiguration() {
    if (_supportedVersion < 1) {
      throw ArgumentError.value(
        _supportedVersion,
        'supportedVersion',
        'Database schema versions must start at version 1.',
      );
    }

    final expectedMigrationCount = _supportedVersion - 1;

    if (_migrations.length != expectedMigrationCount) {
      throw ArgumentError(
        'Database schema version $_supportedVersion requires exactly '
        '$expectedMigrationCount migration step(s), but '
        '${_migrations.length} were registered.',
      );
    }

    for (var index = 0; index < _migrations.length; index++) {
      final migration = _migrations[index];

      final expectedFromVersion = index + 1;
      final expectedToVersion = expectedFromVersion + 1;

      if (migration.fromVersion != expectedFromVersion) {
        throw ArgumentError(
          'Migration at index $index must start at schema version '
          '$expectedFromVersion, but starts at '
          '${migration.fromVersion}.',
        );
      }

      if (migration.toVersion != expectedToVersion) {
        throw ArgumentError(
          'Migration from schema version ${migration.fromVersion} must target '
          'schema version $expectedToVersion, but targets '
          '${migration.toVersion}.',
        );
      }
    }
  }
}
