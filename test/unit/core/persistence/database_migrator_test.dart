@Tags(['core', 'persistence'])
library;

import 'dart:io';

import 'package:axiom/src/core/persistence/database_migrator.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_exception.dart';
import 'package:axiom/src/core/persistence/migrations/database_migration.dart'
    as migrations;
import 'package:axiom/src/core/persistence/migrations/database_migration_exception.dart';
import 'package:axiom/src/core/persistence/unsupported_database_version_exception.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:test/test.dart';

void main() {
  group('DatabaseMigration', () {
    test('preserves fromVersion', () {
      final migration = _migration(2, 3);

      expect(migration.fromVersion, 2);
    });

    test('preserves toVersion', () {
      final migration = _migration(2, 3);

      expect(migration.toVersion, 3);
    });

    test('preserves and invokes the supplied operation', () async {
      var invoked = false;
      Future<void> operation(Transaction _) async {
        invoked = true;
      }
      final migration = _migration(2, 3, operation: operation);
      final database = await _openDatabase();

      expect(migration.operation, same(operation));

      await database.transaction(migration.operation);

      expect(invoked, isTrue);
    });
  });

  group('DatabaseMigrator', () {
    test('constructs for schema version 1 with no migrations', () {
      expect(
        () => DatabaseMigrator(supportedVersion: 1, migrations: []),
        returnsNormally,
      );
    });

    test('constructs for schema version 2 with one 1 to 2 migration', () {
      expect(
        () => DatabaseMigrator(
          supportedVersion: 2,
          migrations: [_migration(1, 2)],
        ),
        returnsNormally,
      );
    });

    test('constructs for schema version 3 with contiguous migrations', () {
      expect(
        () => DatabaseMigrator(
          supportedVersion: 3,
          migrations: [_migration(1, 2), _migration(2, 3)],
        ),
        returnsNormally,
      );
    });

    test('rejects a supported version below 1', () {
      expect(
        () => DatabaseMigrator(supportedVersion: 0, migrations: []),
        throwsArgumentError,
      );
    });

    test('rejects too few migrations', () {
      expect(
        () => DatabaseMigrator(
          supportedVersion: 3,
          migrations: [_migration(1, 2)],
        ),
        throwsArgumentError,
      );
    });

    test('rejects too many migrations', () {
      expect(
        () => DatabaseMigrator(
          supportedVersion: 2,
          migrations: [_migration(1, 2), _migration(2, 3)],
        ),
        throwsArgumentError,
      );
    });

    test('rejects a first migration that does not start at version 1', () {
      expect(
        () => DatabaseMigrator(
          supportedVersion: 2,
          migrations: [_migration(2, 3)],
        ),
        throwsArgumentError,
      );
    });

    test('rejects a version gap', () {
      expect(
        () => DatabaseMigrator(
          supportedVersion: 3,
          migrations: [_migration(1, 2), _migration(3, 4)],
        ),
        throwsArgumentError,
      );
    });

    test('rejects a migration that advances more than one version', () {
      expect(
        () => DatabaseMigrator(
          supportedVersion: 2,
          migrations: [_migration(1, 3)],
        ),
        throwsArgumentError,
      );
    });

    test('rejects a migration that does not advance its version', () {
      expect(
        () => DatabaseMigrator(
          supportedVersion: 2,
          migrations: [_migration(1, 1)],
        ),
        throwsArgumentError,
      );
    });

    test('0 to 1 completes without running a migration', () async {
      final database = await _openDatabase();
      final executedVersions = <int>[];
      final migrator = DatabaseMigrator(
        supportedVersion: 2,
        migrations: [
          _migration(1, 2, operation: (_) async => executedVersions.add(1)),
        ],
      );

      await expectLater(migrator.migrate(database, 0, 1), completes);

      expect(executedVersions, isEmpty);
    });

    test('0 to the current version does not replay historical migrations',
        () async {
      final database = await _openDatabase();
      final executedVersions = <int>[];
      final migrator = DatabaseMigrator(
        supportedVersion: 3,
        migrations: [
          _migration(1, 2, operation: (_) async => executedVersions.add(1)),
          _migration(2, 3, operation: (_) async => executedVersions.add(2)),
        ],
      );

      await migrator.migrate(database, 0, 3);

      expect(executedVersions, isEmpty);
    });

    test('1 to 1 performs no migration work', () async {
      final database = await _openDatabase();
      final executedVersions = <int>[];
      final migrator = DatabaseMigrator(
        supportedVersion: 2,
        migrations: [
          _migration(1, 2, operation: (_) async => executedVersions.add(1)),
        ],
      );

      await migrator.migrate(database, 1, 1);

      expect(executedVersions, isEmpty);
    });

    test('1 to 2 executes only the 1 to 2 migration', () async {
      final database = await _openDatabase();
      final executedVersions = <int>[];
      final migrator = _threeVersionMigrator(executedVersions);

      await migrator.migrate(database, 1, 2);

      expect(executedVersions, [1]);
    });

    test('1 to 3 executes 1 to 2 and then 2 to 3', () async {
      final database = await _openDatabase();
      final executedVersions = <int>[];
      final migrator = _threeVersionMigrator(executedVersions);

      await migrator.migrate(database, 1, 3);

      expect(executedVersions, [1, 2]);
    });

    test('2 to 3 executes only the 2 to 3 migration', () async {
      final database = await _openDatabase();
      final executedVersions = <int>[];
      final migrator = _threeVersionMigrator(executedVersions);

      await migrator.migrate(database, 2, 3);

      expect(executedVersions, [2]);
    });

    test('executes intermediate migrations in ascending schema order',
        () async {
      final database = await _openDatabase();
      final executedVersions = <int>[];
      final migrator = DatabaseMigrator(
        supportedVersion: 4,
        migrations: [
          _migration(1, 2, operation: (_) async => executedVersions.add(1)),
          _migration(2, 3, operation: (_) async => executedVersions.add(2)),
          _migration(3, 4, operation: (_) async => executedVersions.add(3)),
        ],
      );

      await migrator.migrate(database, 1, 4);

      expect(executedVersions, [1, 2, 3]);
    });

    test('rejects a downgrade with both database versions', () async {
      final database = await _openDatabase();

      await expectLater(
        DatabaseMigrator(supportedVersion: 1, migrations: [])
            .migrate(database, 2, 1),
        throwsA(
          isA<UnsupportedDatabaseVersionException>()
              .having(
                (exception) => exception.existingVersion,
                'existingVersion',
                2,
              )
              .having(
                (exception) => exception.supportedVersion,
                'supportedVersion',
                1,
              ),
        ),
      );
    });

    test('rejects a downgrade before executing any migration operation',
        () async {
      final database = await _openDatabase();
      final executedVersions = <int>[];
      final migrator = _threeVersionMigrator(executedVersions);

      await expectLater(
        migrator.migrate(database, 2, 1),
        throwsA(isA<UnsupportedDatabaseVersionException>()),
      );

      expect(executedVersions, isEmpty);
    });

    test('rejects a negative old version with DatabaseMigrationException',
        () async {
      final database = await _openDatabase();

      await expectLater(
        DatabaseMigrator(supportedVersion: 1, migrations: [])
            .migrate(database, -1, 1),
        throwsA(isA<DatabaseMigrationException>()),
      );
    });

    test('rejects a new version above the configured supported version',
        () async {
      final database = await _openDatabase();

      await expectLater(
        DatabaseMigrator(
          supportedVersion: 2,
          migrations: [_migration(1, 2)],
        ).migrate(database, 1, 3),
        throwsA(isA<DatabaseMigrationException>()),
      );
    });

    test('rejects a new version below version 1', () async {
      final database = await _openDatabase();

      await expectLater(
        DatabaseMigrator(supportedVersion: 1, migrations: [])
            .migrate(database, 0, 0),
        throwsA(isA<DatabaseMigrationException>()),
      );
    });

    test('preserves an explicitly thrown DatabaseMigrationException',
        () async {
      final database = await _openDatabase();
      const failure = DatabaseMigrationException(
        fromVersion: 1,
        toVersion: 2,
        message: 'explicit migration failure',
      );
      final migrator = DatabaseMigrator(
        supportedVersion: 2,
        migrations: [
          _migration(1, 2, operation: (_) async => throw failure),
        ],
      );

      await expectLater(
        migrator.migrate(database, 1, 2),
        throwsA(same(failure)),
      );
    });

    test('translates PersistenceRecordException', () async {
      final database = await _openDatabase();

      await _expectTranslatedFailure(
        database: database,
        error: const PersistenceRecordException(reason: 'invalid record'),
        message:
            'Persisted data could not be interpreted during database migration.',
      );
    });

    test('translates FormatException', () async {
      final database = await _openDatabase();

      await _expectTranslatedFailure(
        database: database,
        error: const FormatException('invalid value'),
        message:
            'Persisted data contained an invalid value during database migration.',
      );
    });

    test('translates DatabaseException', () async {
      final database = await _openDatabase();

      await _expectTranslatedFailure(
        database: database,
        error: DatabaseException.badParam('invalid database operation'),
        message: 'A database operation failed during database migration.',
      );
    });

    test('translates FileSystemException', () async {
      final database = await _openDatabase();

      await _expectTranslatedFailure(
        database: database,
        error: const FileSystemException('write failed'),
        message: 'The database could not be persisted during database migration.',
      );
    });

    test('translated failures preserve the precise migration step versions',
        () async {
      final database = await _openDatabase();
      final migrator = DatabaseMigrator(
        supportedVersion: 3,
        migrations: [
          _migration(1, 2),
          _migration(
            2,
            3,
            operation: (_) async {
              throw const FormatException('invalid value');
            },
          ),
        ],
      );

      await expectLater(
        migrator.migrate(database, 1, 3),
        throwsA(
          isA<DatabaseMigrationException>()
              .having((exception) => exception.fromVersion, 'fromVersion', 2)
              .having((exception) => exception.toVersion, 'toVersion', 3),
        ),
      );
    });

    test('does not translate programmer errors', () async {
      final database = await _openDatabase();
      final error = StateError('programmer error');
      final migrator = DatabaseMigrator(
        supportedVersion: 2,
        migrations: [
          _migration(1, 2, operation: (_) async => throw error),
        ],
      );

      await expectLater(
        migrator.migrate(database, 1, 2),
        throwsA(same(error)),
      );
    });

    test('commits successful migration writes', () async {
      final database = await _openDatabase();
      final store = StoreRef<int, Map<String, Object?>>('migration-data');
      final migrator = DatabaseMigrator(
        supportedVersion: 2,
        migrations: [
          _migration(
            1,
            2,
            operation: (transaction) async {
              await store.record(1).put(transaction, {'value': 'migrated'});
            },
          ),
        ],
      );

      await migrator.migrate(database, 1, 2);

      expect(await store.record(1).get(database), {'value': 'migrated'});
    });

    test('rolls back all writes when a later migration fails', () async {
      final database = await _openDatabase();
      final firstStore = StoreRef<int, Map<String, Object?>>('first-migration');
      final secondStore = StoreRef<int, Map<String, Object?>>(
        'second-migration',
      );
      const failure = DatabaseMigrationException(
        fromVersion: 2,
        toVersion: 3,
        message: 'later migration failed',
      );
      final migrator = DatabaseMigrator(
        supportedVersion: 3,
        migrations: [
          _migration(
            1,
            2,
            operation: (transaction) async {
              await firstStore.record(1).put(transaction, {'value': 'first'});
            },
          ),
          _migration(
            2,
            3,
            operation: (transaction) async {
              await secondStore.record(1).put(transaction, {'value': 'second'});
              throw failure;
            },
          ),
        ],
      );

      await expectLater(
        migrator.migrate(database, 1, 3),
        throwsA(same(failure)),
      );

      expect(await firstStore.record(1).get(database), isNull);
      expect(await secondStore.record(1).get(database), isNull);
    });

    test('translates a file-system error from the migration transaction',
        () async {
      final database = MockDatabase();
      when(() => database.transaction<Null>(any())).thenThrow(
        const FileSystemException('transaction write failed'),
      );

      final migrator = DatabaseMigrator(
        supportedVersion: 2,
        migrations: [_migration(1, 2)],
      );

      await expectLater(
        migrator.migrate(database, 1, 2),
        throwsA(
          isA<DatabaseMigrationException>()
              .having((exception) => exception.fromVersion, 'fromVersion', 1)
              .having((exception) => exception.toVersion, 'toVersion', 2)
              .having(
                (exception) => exception.message,
                'message',
                'The database migration transaction could not be persisted.',
              ),
        ),
      );
    });

    test('translates a database error from the migration transaction',
        () async {
      final database = MockDatabase();
      when(() => database.transaction<Null>(any())).thenThrow(
        DatabaseException.closed('transaction failed'),
      );

      final migrator = DatabaseMigrator(
        supportedVersion: 2,
        migrations: [_migration(1, 2)],
      );

      await expectLater(
        migrator.migrate(database, 1, 2),
        throwsA(
          isA<DatabaseMigrationException>().having(
            (exception) => exception.message,
            'message',
            'The database migration transaction failed.',
          ),
        ),
      );
    });
  });
}

class MockDatabase extends Mock implements Database {}

migrations.DatabaseMigration _migration(
  int fromVersion,
  int toVersion, {
  Future<void> Function(Transaction transaction)? operation,
}) {
  return migrations.DatabaseMigration(
    fromVersion: fromVersion,
    toVersion: toVersion,
    operation: operation ?? (_) async {},
  );
}

DatabaseMigrator _threeVersionMigrator(List<int> executedVersions) {
  return DatabaseMigrator(
    supportedVersion: 3,
    migrations: [
      _migration(1, 2, operation: (_) async => executedVersions.add(1)),
      _migration(2, 3, operation: (_) async => executedVersions.add(2)),
    ],
  );
}

Future<void> _expectTranslatedFailure({
  required Database database,
  required Object error,
  required String message,
}) async {
  final migrator = DatabaseMigrator(
    supportedVersion: 2,
    migrations: [
      _migration(1, 2, operation: (_) async => throw error),
    ],
  );

  await expectLater(
    migrator.migrate(database, 1, 2),
    throwsA(
      isA<DatabaseMigrationException>()
          .having((exception) => exception.fromVersion, 'fromVersion', 1)
          .having((exception) => exception.toVersion, 'toVersion', 2)
          .having((exception) => exception.message, 'message', message),
    ),
  );
}

var _databaseNumber = 0;

Future<Database> _openDatabase() async {
  final database = await databaseFactoryMemory.openDatabase(
    'database-migrator-test-${_databaseNumber++}',
  );
  addTearDown(database.close);
  return database;
}
