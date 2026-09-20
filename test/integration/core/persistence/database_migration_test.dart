@Tags(['integration', 'core', 'data', 'persistence'])
library;

import 'package:axiom/src/core/persistence/database_migrator.dart';
import 'package:axiom/src/core/persistence/migrations/database_migration.dart';
import 'package:axiom/src/core/persistence/migrations/database_migration_exception.dart';
import 'package:axiom/src/core/persistence/sembast_stores.dart';
import 'package:sembast/sembast_io.dart';
import 'package:test/test.dart';

import '../../../fixtures/core/persistence/persistence_test_environment.dart';

const _version1 = 1;
const _version2 = 2;
const _version3 = 3;
const _recordKey = 'migration-record';

const _version1Record = <String, Object?>{
  'schemaVersion': _version1,
  'value': 'original',
};

void main() {
  group('Database migration integration', () {
    test(
      'upgrades persisted version-1 data through every migration step',
      () async {
        // Given
        final environment = await PersistenceTestEnvironment.createIo();
        final store = SembastStores.settings;
        final rawVersion1 = await environment.openRawDatabase(
          version: _version1,
        );

        await store
            .record(_recordKey)
            .put(rawVersion1.database, _version1Record);
        await rawVersion1.close();

        Map<String, Object?>? secondMigrationInput;
        final migrator = DatabaseMigrator(
          supportedVersion: _version3,
          migrations: [
            DatabaseMigration(
              fromVersion: _version1,
              toVersion: _version2,
              operation: (transaction) async {
                await store.record(_recordKey).put(transaction, {
                  'schemaVersion': _version2,
                  'value': 'changed-by-1-to-2',
                  'firstMigrationCommitted': true,
                });
              },
            ),
            DatabaseMigration(
              fromVersion: _version2,
              toVersion: _version3,
              operation: (transaction) async {
                secondMigrationInput = await store
                    .record(_recordKey)
                    .get(transaction);

                await store.record(_recordKey).put(transaction, {
                  'schemaVersion': _version3,
                  'value': 'changed-by-2-to-3',
                  'firstMigrationCommitted': true,
                });
              },
            ),
          ],
        );

        // When
        final database = await _openAtVersion(
          environment,
          version: _version3,
          migrator: migrator,
        );

        // Then
        expect(database.version, _version3);
        expect(secondMigrationInput, {
          'schemaVersion': _version2,
          'value': 'changed-by-1-to-2',
          'firstMigrationCommitted': true,
        });
        expect(await store.record(_recordKey).get(database), {
          'schemaVersion': _version3,
          'value': 'changed-by-2-to-3',
          'firstMigrationCommitted': true,
        });

        await database.close();
      },
    );

    test(
      'rolls back a failed multi-version upgrade and retries from version 1',
      () async {
        // Given
        final environment = await PersistenceTestEnvironment.createIo();
        final store = SembastStores.settings;
        final rawVersion1 = await environment.openRawDatabase(
          version: _version1,
        );

        await store
            .record(_recordKey)
            .put(rawVersion1.database, _version1Record);
        await rawVersion1.close();

        const migrationFailure = DatabaseMigrationException(
          fromVersion: _version2,
          toVersion: _version3,
          message: 'The final migration failed.',
        );
        final failingMigrator = _createMigrator(
          store: store,
          finalMigration: (transaction) async {
            await store.record(_recordKey).put(transaction, {
              'schemaVersion': _version3,
              'value': 'partially-transformed',
            });
            throw migrationFailure;
          },
        );

        // When
        await expectLater(
          _openAtVersion(
            environment,
            version: _version3,
            migrator: failingMigrator,
          ),
          throwsA(same(migrationFailure)),
        );

        // Then: the failed open still exposes the old schema and data when
        // the file is reopened at its pre-migration version.
        final rolledBackVersion1 = await environment.openRawDatabase(
          version: _version1,
        );

        expect(rolledBackVersion1.database.version, _version1);
        expect(
          await store.record(_recordKey).get(rolledBackVersion1.database),
          _version1Record,
        );
        await rolledBackVersion1.close();

        var retryStartedWithVersion1Data = false;
        final successfulMigrator = _createMigrator(
          store: store,
          firstMigration: (transaction) async {
            final record = await store.record(_recordKey).get(transaction);

            if (record == null || record['schemaVersion'] != _version1) {
              throw StateError(
                'The retry did not start from the version-1 representation.',
              );
            }

            retryStartedWithVersion1Data = true;
            await store.record(_recordKey).put(transaction, {
              'schemaVersion': _version2,
              'value': 'changed-by-retry-1-to-2',
              'firstMigrationCommitted': true,
            });
          },
          finalMigration: (transaction) async {
            final record = await store.record(_recordKey).get(transaction);

            if (record == null || record['schemaVersion'] != _version2) {
              throw StateError(
                'The retry did not observe the completed first migration.',
              );
            }

            await store.record(_recordKey).put(transaction, {
              'schemaVersion': _version3,
              'value': 'changed-by-retry-2-to-3',
              'firstMigrationCommitted': true,
            });
          },
        );

        // When
        final retriedDatabase = await _openAtVersion(
          environment,
          version: _version3,
          migrator: successfulMigrator,
        );

        // Then
        expect(retryStartedWithVersion1Data, isTrue);
        expect(retriedDatabase.version, _version3);
        expect(await store.record(_recordKey).get(retriedDatabase), {
          'schemaVersion': _version3,
          'value': 'changed-by-retry-2-to-3',
          'firstMigrationCommitted': true,
        });

        await retriedDatabase.close();
      },
    );

    test(
      'does not replay historical migrations for a fresh later-version database',
      () async {
        // Given
        final environment = await PersistenceTestEnvironment.createIo();
        final executedMigrations = <String>[];
        final migrator = DatabaseMigrator(
          supportedVersion: _version3,
          migrations: [
            DatabaseMigration(
              fromVersion: _version1,
              toVersion: _version2,
              operation: (_) async => executedMigrations.add('1-to-2'),
            ),
            DatabaseMigration(
              fromVersion: _version2,
              toVersion: _version3,
              operation: (_) async => executedMigrations.add('2-to-3'),
            ),
          ],
        );

        // When
        final database = await _openAtVersion(
          environment,
          version: _version3,
          migrator: migrator,
        );

        // Then
        expect(database.version, _version3);
        expect(executedMigrations, isEmpty);

        await database.close();
      },
    );
  });
}

DatabaseMigrator _createMigrator({
  required StoreRef<String, Map<String, Object?>> store,
  Future<void> Function(Transaction transaction)? firstMigration,
  required Future<void> Function(Transaction transaction) finalMigration,
}) {
  return DatabaseMigrator(
    supportedVersion: _version3,
    migrations: [
      DatabaseMigration(
        fromVersion: _version1,
        toVersion: _version2,
        operation:
            firstMigration ??
            (transaction) async {
              await store.record(_recordKey).put(transaction, {
                'schemaVersion': _version2,
                'value': 'changed-by-1-to-2',
                'firstMigrationCommitted': true,
              });
            },
      ),
      DatabaseMigration(
        fromVersion: _version2,
        toVersion: _version3,
        operation: finalMigration,
      ),
    ],
  );
}

Future<Database> _openAtVersion(
  PersistenceTestEnvironment environment, {
  required int version,
  required DatabaseMigrator migrator,
}) {
  return databaseFactoryIo.openDatabase(
    environment.databasePath,
    version: version,
    onVersionChanged: migrator.migrate,
    mode: DatabaseMode.create,
  );
}
