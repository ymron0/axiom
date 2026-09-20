@Tags(['integration', 'core', 'data', 'persistence'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:axiom/src/core/persistence/database_schema.dart';
import 'package:axiom/src/core/persistence/failures/database_open_failure.dart';
import 'package:axiom/src/core/persistence/failures/database_version_failure.dart';
import 'package:axiom/src/core/persistence/sembast_stores.dart';
import 'package:axiom/src/core/persistence/database_integrity_checker.dart';
import 'package:axiom/src/core/persistence/failures/database_integrity_failure.dart';
import 'package:sembast/sembast_io.dart';
import 'package:test/test.dart';

import '../../../fixtures/core/persistence/persistence_test_environment.dart';

const _testRecordKey = 'integration-test-record';

const _testRecord = <String, Object?>{
  'name': 'Persisted value',
  'quantity': 42,
};

void main() {
  group('Sembast database lifecycle integration', () {
    test('creates and opens a new database', () async {
      final environment = await PersistenceTestEnvironment.createIo();
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
      final environment = await PersistenceTestEnvironment.createIo();

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
        final environment = await PersistenceTestEnvironment.createIo();

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
        final environment = await PersistenceTestEnvironment.createIo();

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
        final environment = await PersistenceTestEnvironment.createIo();

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
        final environment = await PersistenceTestEnvironment.createIo();
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
        final environment = await PersistenceTestEnvironment.createIo();
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

    test(
      'integrity failure closes database without destroying persisted data',
      () async {
        // Given
        final environment = await PersistenceTestEnvironment.createIo(
          prefix: 'persistence-integrity-failure-',
        );

        // Prepare a valid existing database independently of the lifecycle.
        final rawDatabase = await environment.openRawDatabase(
          version: DatabaseSchema.version,
        );

        await SembastStores.settings
            .record(_testRecordKey)
            .put(rawDatabase.database, _testRecord);

        await rawDatabase.close();

        expect(await environment.databaseFile.exists(), isTrue);

        // The database itself is valid. Force the integrity layer to reject it by
        // requiring a different version after Sembast has successfully opened it.
        //
        // This allows the test to exercise the lifecycle branch where:
        //
        // 1. raw opening succeeds;
        // 2. integrity validation fails;
        // 3. the lifecycle closes the opened database;
        // 4. persisted data remains untouched.
        final rejectingLifecycle = environment.createLifecycle(
          integrityChecker: DatabaseIntegrityChecker(
            expectedVersion: DatabaseSchema.version + 1,
          ),
        );

        // When
        final rejectedResult = await rejectingLifecycle.open();

        // Then
        expect(rejectedResult.isFailure, isTrue);
        expect(rejectedResult.isSuccess, isFalse);
        expect(rejectedResult.valueOrNull, isNull);
        expect(rejectedResult.failureOrNull, isA<DatabaseIntegrityFailure>());

        // A database that did not pass validation must never remain published as
        // usable through the lifecycle.
        expect(rejectingLifecycle.isOpen, isFalse);

        // Integrity failure is non-destructive.
        expect(await environment.databaseFile.exists(), isTrue);

        // When
        //
        // Create completely new production infrastructure using the normal
        // integrity policy.
        final healthyLifecycle = environment.createLifecycle();

        final healthyOpenResult = await healthyLifecycle.open();

        // Then
        //
        // The same physical database can still be opened and its previous content
        // is intact.
        expect(healthyOpenResult.isSuccess, isTrue);
        expect(healthyOpenResult.failureOrNull, isNull);
        expect(healthyLifecycle.isOpen, isTrue);

        final persistedRecord = await SembastStores.settings
            .record(_testRecordKey)
            .get(healthyOpenResult.valueOrNull!);

        expect(persistedRecord, equals(_testRecord));
      },
    );
  });
}
