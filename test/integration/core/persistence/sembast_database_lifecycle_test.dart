@Tags(['integration', 'core', 'persistence'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:axiom/src/core/persistence/database_lifecycle_service.dart';
import 'package:axiom/src/core/persistence/database_schema.dart';
import 'package:axiom/src/core/persistence/failures/database_open_failure.dart';
import 'package:axiom/src/core/persistence/failures/database_version_failure.dart';
import 'package:axiom/src/core/persistence/sembast_database.dart';
import 'package:axiom/src/core/persistence/sembast_stores.dart';
import 'package:path/path.dart' as p;
import 'package:sembast/sembast_io.dart';
import 'package:test/test.dart';

const _testRecordKey = 'integration-test-record';

const _testRecord = <String, Object?>{
  'name': 'Persisted value',
  'quantity': 42,
};

void main() {
  group('Sembast database lifecycle integration', () {
    test('creates and opens a new database', () async {
      final environment = await _TestEnvironment.create();
      final lifecycle = environment.createLifecycle();

      // Use a nested database directory so we can prove that opening creates
      // it rather than relying on Directory.systemTemp.createTemp().
      expect(await environment.rootDirectory.exists(), isFalse);
      expect(lifecycle.isOpen, isFalse);
      expect(lifecycle.isOpen, isFalse);

      final result = await lifecycle.open();

      expect(result.isSuccess, isTrue);
      expect(result.failureOrNull, isNull);
      expect(result.valueOrNull, isNotNull);

      final database = result.valueOrNull!;

      expect(await environment.rootDirectory.exists(), isTrue);
      expect(await File(environment.databasePath).exists(), isTrue);
      expect(database.version, DatabaseSchema.version);
      expect(lifecycle.isOpen, isTrue);
      expect(lifecycle.isOpen, isTrue);
    });

    test('persisted data survives close and application restart', () async {
      final environment = await _TestEnvironment.create();

      final firstLifecycle = environment.createLifecycle();

      final firstOpenResult = await firstLifecycle.open();

      expect(firstOpenResult.isSuccess, isTrue);

      final firstDatabase = firstOpenResult.valueOrNull!;

      await SembastStores.settings
          .record(_testRecordKey)
          .put(firstDatabase, _testRecord);

      final firstCloseResult = await firstLifecycle.close();

      expect(firstCloseResult.isSuccess, isTrue);
      expect(firstLifecycle.isOpen, isFalse);

      // Construct completely new infrastructure objects to simulate a real
      // application restart.
      final secondLifecycle = environment.createLifecycle();

      final secondOpenResult = await secondLifecycle.open();

      expect(secondOpenResult.isSuccess, isTrue);

      final secondDatabase = secondOpenResult.valueOrNull!;

      final persistedRecord = await SembastStores.settings
          .record(_testRecordKey)
          .get(secondDatabase);

      expect(persistedRecord, equals(_testRecord));
      expect(secondLifecycle.isOpen, isTrue);
    });

    test(
      'opens an existing database with the supported schema version',
      () async {
        final environment = await _TestEnvironment.create();

        // Create the database independently of the production lifecycle. This
        // simulates a database that already exists before application startup.
        final rawDatabase = await environment.openRawDatabase(
          version: DatabaseSchema.version,
        );

        await SembastStores.settings
            .record(_testRecordKey)
            .put(rawDatabase.database, _testRecord);

        await rawDatabase.close();

        final lifecycle = environment.createLifecycle();

        final result = await lifecycle.open();

        expect(result.isSuccess, isTrue);
        expect(result.failureOrNull, isNull);

        final database = result.valueOrNull!;

        expect(database.version, DatabaseSchema.version);
        expect(lifecycle.isOpen, isTrue);

        final persistedRecord = await SembastStores.settings
            .record(_testRecordKey)
            .get(database);

        expect(persistedRecord, equals(_testRecord));
      },
    );

    test(
      'rejects a database created with a newer schema without modifying it',
      () async {
        final environment = await _TestEnvironment.create();

        final newerVersion = DatabaseSchema.version + 1;

        // Simulate a database created by a future version of the application.
        final futureDatabase = await environment.openRawDatabase(
          version: newerVersion,
        );

        await SembastStores.settings
            .record(_testRecordKey)
            .put(futureDatabase.database, _testRecord);

        await futureDatabase.close();

        final databaseFile = File(environment.databasePath);

        expect(await databaseFile.exists(), isTrue);

        final lifecycle = environment.createLifecycle();

        final result = await lifecycle.open();

        expect(result.isFailure, isTrue);
        expect(result.isSuccess, isFalse);
        expect(result.valueOrNull, isNull);
        expect(result.failureOrNull, isA<DatabaseVersionFailure>());

        final failure = result.failureOrNull! as DatabaseVersionFailure;

        expect(failure.existingVersion, newerVersion);
        expect(failure.supportedVersion, DatabaseSchema.version);

        expect(lifecycle.isOpen, isFalse);
        expect(lifecycle.isOpen, isFalse);

        // Downgrade protection must not delete the database.
        expect(await databaseFile.exists(), isTrue);

        // Reopen using the newer schema version to prove that the failed
        // downgrade attempt did not modify or erase its contents.
        final reopenedFutureDatabase = await environment.openRawDatabase(
          version: newerVersion,
        );

        expect(reopenedFutureDatabase.database.version, newerVersion);

        final persistedRecord = await SembastStores.settings
            .record(_testRecordKey)
            .get(reopenedFutureDatabase.database);

        expect(persistedRecord, equals(_testRecord));

        await reopenedFutureDatabase.close();
      },
    );

    test(
      'corrupt database fails opening without deleting or replacing file',
      () async {
        final environment = await _TestEnvironment.create();

        await environment.rootDirectory.create(recursive: true);

        final databaseFile = File(environment.databasePath);

        // This is deliberately not valid Sembast database content.
        final originalBytes = utf8.encode(
          'This is deliberately corrupt database content.\n'
          'It must survive a failed opening attempt.\n',
        );

        await databaseFile.writeAsBytes(originalBytes, flush: true);

        expect(await databaseFile.exists(), isTrue);
        expect(await databaseFile.readAsBytes(), equals(originalBytes));

        final lifecycle = environment.createLifecycle();

        final result = await lifecycle.open();

        expect(result.isFailure, isTrue);
        expect(result.isSuccess, isFalse);
        expect(result.valueOrNull, isNull);
        expect(result.failureOrNull, isA<DatabaseOpenFailure>());

        expect(lifecycle.isOpen, isFalse);
        expect(lifecycle.isOpen, isFalse);

        // The most important assertion in this test: corruption must never
        // trigger an automatic database reset.
        expect(await databaseFile.exists(), isTrue);

        final bytesAfterFailedOpen = await databaseFile.readAsBytes();

        expect(bytesAfterFailedOpen, equals(originalBytes));
      },
    );

    test(
      'recovery closes and reopens database without losing persisted data',
      () async {
        final environment = await _TestEnvironment.create();
        final lifecycle = environment.createLifecycle();

        final openResult = await lifecycle.open();

        expect(openResult.isSuccess, isTrue);

        final databaseBeforeRecovery = openResult.valueOrNull!;

        await SembastStores.settings
            .record(_testRecordKey)
            .put(databaseBeforeRecovery, _testRecord);

        expect(lifecycle.isOpen, isTrue);
        expect(lifecycle.isOpen, isTrue);

        final recoveryResult = await lifecycle.recover();

        expect(recoveryResult.isSuccess, isTrue);
        expect(recoveryResult.failureOrNull, isNull);

        final databaseAfterRecovery = recoveryResult.valueOrNull!;

        expect(lifecycle.isOpen, isTrue);
        expect(lifecycle.isOpen, isTrue);

        final persistedRecord = await SembastStores.settings
            .record(_testRecordKey)
            .get(databaseAfterRecovery);

        expect(persistedRecord, equals(_testRecord));
      },
    );

    test(
      'supports repeated open and close cycles without losing data',
      () async {
        final environment = await _TestEnvironment.create();
        final lifecycle = environment.createLifecycle();

        // First open.
        final firstOpenResult = await lifecycle.open();

        expect(firstOpenResult.isSuccess, isTrue);

        final firstDatabase = firstOpenResult.valueOrNull!;

        await SembastStores.settings
            .record(_testRecordKey)
            .put(firstDatabase, _testRecord);

        expect(lifecycle.isOpen, isTrue);

        // First close.
        final firstCloseResult = await lifecycle.close();

        expect(firstCloseResult.isSuccess, isTrue);
        expect(lifecycle.isOpen, isFalse);
        expect(lifecycle.isOpen, isFalse);

        // Second open.
        final secondOpenResult = await lifecycle.open();

        expect(secondOpenResult.isSuccess, isTrue);
        expect(lifecycle.isOpen, isTrue);

        final secondDatabase = secondOpenResult.valueOrNull!;

        final recordAfterSecondOpen = await SembastStores.settings
            .record(_testRecordKey)
            .get(secondDatabase);

        expect(recordAfterSecondOpen, equals(_testRecord));

        // Second close.
        final secondCloseResult = await lifecycle.close();

        expect(secondCloseResult.isSuccess, isTrue);
        expect(lifecycle.isOpen, isFalse);

        // Third open.
        final thirdOpenResult = await lifecycle.open();

        expect(thirdOpenResult.isSuccess, isTrue);
        expect(lifecycle.isOpen, isTrue);

        final thirdDatabase = thirdOpenResult.valueOrNull!;

        final recordAfterThirdOpen = await SembastStores.settings
            .record(_testRecordKey)
            .get(thirdDatabase);

        expect(recordAfterThirdOpen, equals(_testRecord));
      },
    );
  });
}

/// Owns filesystem and database resources used by one integration test.
///
/// Each test receives a unique temporary parent directory. The actual
/// database root is a nested directory so tests can verify whether production
/// opening creates the root directory.
///
/// All created database wrappers and raw Sembast handles are closed before the
/// temporary directory is deleted.
final class _TestEnvironment {
  final Directory parentDirectory;
  final Directory rootDirectory;

  final List<SembastDatabase> _managedDatabases = <SembastDatabase>[];
  final List<_RawDatabaseHandle> _rawDatabases = <_RawDatabaseHandle>[];

  _TestEnvironment({
    required this.parentDirectory,
    required this.rootDirectory,
  });

  /// Creates and registers an isolated integration-test environment.
  static Future<_TestEnvironment> create() async {
    final parentDirectory = await Directory.systemTemp.createTemp(
      'sembast-lifecycle-integration-test-',
    );

    final environment = _TestEnvironment(
      parentDirectory: parentDirectory,
      rootDirectory: Directory(p.join(parentDirectory.path, 'database')),
    );

    addTearDown(environment.dispose);

    return environment;
  }

  /// Path of the physical Sembast database file.
  String get databasePath =>
      p.join(rootDirectory.path, DatabaseSchema.fileName);

  /// Creates production database infrastructure for this environment.
  ///
  /// Every created wrapper is tracked and closed during teardown.
  DatabaseLifecycleService createLifecycle() {
    final database = SembastDatabase.io(rootPath: rootDirectory.path);

    _managedDatabases.add(database);

    return DatabaseLifecycleService(database: database);
  }

  /// Opens the database directly through Sembast.
  ///
  /// This deliberately bypasses the production lifecycle and is used to
  /// prepare persistence states that production code must subsequently handle,
  /// such as an already-existing database or one created by a newer schema.
  Future<_RawDatabaseHandle> openRawDatabase({required int version}) async {
    await rootDirectory.create(recursive: true);

    final database = await databaseFactoryIo.openDatabase(
      databasePath,
      version: version,

      // Be explicit here too. The tests should not depend on Sembast's
      // destructive `neverFails` default mode.
      mode: DatabaseMode.create,
    );

    final handle = _RawDatabaseHandle(database);

    _rawDatabases.add(handle);

    return handle;
  }

  /// Closes all database resources and removes temporary files.
  ///
  /// Cleanup attempts continue even when one resource fails to close. The
  /// first cleanup error is rethrown after every remaining cleanup action has
  /// been attempted.
  Future<void> dispose() async {
    Object? firstError;
    StackTrace? firstStackTrace;

    for (final database in _managedDatabases.reversed) {
      try {
        await database.close();
      } catch (error, stackTrace) {
        firstError ??= error;
        firstStackTrace ??= stackTrace;
      }
    }

    for (final database in _rawDatabases.reversed) {
      try {
        await database.close();
      } catch (error, stackTrace) {
        firstError ??= error;
        firstStackTrace ??= stackTrace;
      }
    }

    try {
      if (await parentDirectory.exists()) {
        await parentDirectory.delete(recursive: true);
      }
    } catch (error, stackTrace) {
      firstError ??= error;
      firstStackTrace ??= stackTrace;
    }

    if (firstError != null) {
      Error.throwWithStackTrace(firstError, firstStackTrace!);
    }
  }
}

/// Provides idempotent ownership of a directly opened Sembast database.
///
/// Some integration scenarios need to close a raw database during the test and
/// then reopen the same file. Making [close] idempotent allows the environment
/// teardown to safely call it again.
final class _RawDatabaseHandle {
  final Database database;

  bool _closed = false;

  _RawDatabaseHandle(this.database);

  /// Closes the raw database once.
  Future<void> close() async {
    if (_closed) {
      return;
    }

    await database.close();

    _closed = true;
  }
}
