import 'dart:io';

import 'package:axiom/src/core/persistence/database_integrity_checker.dart';
import 'package:axiom/src/core/persistence/failures/database_close_failure.dart';
import 'package:axiom/src/core/persistence/failures/database_open_failure.dart';
import 'package:axiom/src/core/persistence/failures/database_recovery_failure.dart';
import 'package:axiom/src/core/persistence/failures/database_version_failure.dart';
import 'package:axiom/src/core/persistence/failures/persistence_failure.dart';
import 'package:axiom/src/core/persistence/sembast_database.dart';
import 'package:axiom/src/core/persistence/unsupported_database_version_exception.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:sembast/sembast.dart';

/// Coordinates the validated lifecycle of the persistent database.
///
/// [SembastDatabase] owns low-level Sembast mechanics. This service owns the
/// higher-level policy that determines whether an opened database is safe for
/// the rest of the application to use.
///
/// ## Open sequence
///
/// Opening performs:
///
/// 1. raw Sembast opening;
/// 2. schema migration through `SembastDatabase`;
/// 3. integrity validation;
/// 4. publication of the validated database.
///
/// A database is never exposed by this service before all four stages succeed.
///
/// ## Failure translation
///
/// Expected filesystem and Sembast operational exceptions are translated into
/// typed [PersistenceFailure] values.
///
/// Programmer errors and violated internal assumptions are intentionally not
/// converted into persistence failures.
///
/// ## Recovery
///
/// Recovery is non-destructive. It closes the current database state and then
/// performs the normal validated open workflow again.
///
/// Recovery never deletes or replaces the database.
final class DatabaseLifecycleService {
  final SembastDatabase _database;
  final DatabaseIntegrityChecker _integrityChecker;

  Database? _validatedDatabase;
  Future<Result<Database, PersistenceFailure>>? _opening;

  /// Creates a database lifecycle service.
  ///
  /// Production code normally supplies only [database].
  ///
  /// [integrityChecker] is injectable to keep lifecycle behavior independently
  /// testable.
  DatabaseLifecycleService({
    required SembastDatabase database,
    DatabaseIntegrityChecker? integrityChecker,
  }) : _database = // ignore: prefer_initializing_formals
           database,
       _integrityChecker = integrityChecker ?? DatabaseIntegrityChecker();

  /// Whether a database is currently open and has passed integrity validation.
  ///
  /// Raw Sembast openness alone is insufficient. The database is considered
  /// open at this layer only after validation has succeeded.
  bool get isOpen => _validatedDatabase != null && _database.isOpen;

  /// Opens and validates the persistent database.
  ///
  /// Repeated calls reuse the already validated database.
  ///
  /// Concurrent callers share one lifecycle opening operation, which prevents
  /// duplicate integrity checks and ensures all callers observe the same
  /// opening outcome.
  Future<Result<Database, PersistenceFailure>> open() async {
    final currentDatabase = _validatedDatabase;

    if (currentDatabase != null && _database.isOpen) {
      return Success<Database>(currentDatabase);
    }

    // Discard stale validated state if the raw database is no longer open.
    if (!_database.isOpen) {
      _validatedDatabase = null;
    }

    final currentOpening = _opening;

    if (currentOpening != null) {
      return currentOpening;
    }

    final opening = _openAndValidate();

    _opening = opening;

    try {
      return await opening;
    } finally {
      _opening = null;
    }
  }

  /// Closes the persistent database.
  ///
  /// Closing an already closed database is successful.
  ///
  /// If opening is currently in progress, close waits for the lifecycle open
  /// operation to finish first.
  Future<Result<Null, PersistenceFailure>> close() async {
    final opening = _opening;

    if (opening != null) {
      await opening;
    }

    // Stop advertising the database as validated before actual shutdown.
    //
    // If Sembast reports a close error, callers must still not receive the
    // database through this lifecycle service as though it were healthy.
    _validatedDatabase = null;

    try {
      await _database.close();

      return const Success<Null>(null);
    } on FileSystemException {
      return const DatabaseCloseFailure(
        message: 'Failed to close the local database.',
      );
    } on DatabaseException {
      return const DatabaseCloseFailure(
        message: 'Failed to close the local database.',
      );
    }
  }

  /// Attempts non-destructive database recovery.
  ///
  /// Recovery means:
  ///
  /// 1. return to a clean closed lifecycle state;
  /// 2. perform the normal [open] workflow again;
  /// 3. rerun migrations if required;
  /// 4. rerun integrity validation.
  ///
  /// Recovery never deletes, resets, or replaces persisted data.
  ///
  /// A cleanup failure becomes [DatabaseRecoveryFailure].
  ///
  /// Once cleanup succeeds, any failure from [open] is preserved unchanged.
  /// For example, an unsupported version remains `DatabaseVersionFailure`
  /// rather than being hidden behind `DatabaseRecoveryFailure`.
  Future<Result<Database, PersistenceFailure>> recover() async {
    final closeResult = await close();

    if (closeResult.isFailure) {
      return const DatabaseRecoveryFailure(
        message: 'Database recovery could not establish a clean closed state.',
      );
    }

    return open();
  }

  /// Performs one complete raw-open plus integrity-validation operation.
  Future<Result<Database, PersistenceFailure>> _openAndValidate() async {
    final Database database;

    try {
      database = await _database.open();
    } on UnsupportedDatabaseVersionException catch (error) {
      return DatabaseVersionFailure(
        existingVersion: error.existingVersion,
        supportedVersion: error.supportedVersion,
        message:
            'Database schema version ${error.existingVersion} is newer than '
            'supported version ${error.supportedVersion}.',
      );
    } on FileSystemException {
      return const DatabaseOpenFailure(
        message: 'Failed to open the local database.',
      );
    } on FormatException {
      // A malformed/corrupted Sembast file can fail parsing before a Database
      // instance can be returned. That is therefore an opening failure rather
      // than a post-open integrity failure.
      return const DatabaseOpenFailure(
        message: 'The local database could not be read.',
      );
    } on DatabaseException {
      return const DatabaseOpenFailure(
        message: 'Failed to open the local database.',
      );
    }

    final integrityResult = await _integrityChecker.check(database);

    if (integrityResult.isFailure) {
      final integrityFailure = integrityResult.failureOrNull!;

      // The raw database opened, but it must not remain active after failing
      // integrity validation.
      final cleanupFailure = await _closeAfterFailedValidation();

      if (cleanupFailure != null) {
        return cleanupFailure;
      }

      return integrityFailure;
    }

    // Publish the database only after integrity validation succeeds.
    _validatedDatabase = database;

    return Success<Database>(database);
  }

  /// Closes a database that opened successfully but failed validation.
  ///
  /// This method deliberately bypasses public [close].
  ///
  /// Calling [close] from inside [_openAndValidate] would wait on [_opening],
  /// which is the operation currently executing, and would therefore
  /// deadlock.
  Future<DatabaseRecoveryFailure?> _closeAfterFailedValidation() async {
    _validatedDatabase = null;

    try {
      await _database.close();

      return null;
    } on FileSystemException {
      return const DatabaseRecoveryFailure(
        message:
            'Database integrity validation failed and the database could not '
            'be closed safely.',
      );
    } on DatabaseException {
      return const DatabaseRecoveryFailure(
        message:
            'Database integrity validation failed and the database could not '
            'be closed safely.',
      );
    }
  }
}
