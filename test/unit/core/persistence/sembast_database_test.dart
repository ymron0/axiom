@Tags(['core', 'data', 'persistence'])
library;

import 'package:axiom/src/core/persistence/database_migrator.dart';
import 'package:axiom/src/core/persistence/database_schema.dart';
import 'package:axiom/src/core/persistence/migrations/database_migration.dart';
import 'package:axiom/src/core/persistence/sembast_database.dart';
import 'package:axiom/src/core/persistence/unsupported_database_version_exception.dart';
import 'package:path/path.dart' as p;
import 'package:sembast/sembast_memory.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../fixtures/core/persistence/persistence_test_environment.dart';
import '../../../mocks/database_factory_mock.dart';

void main() {
  group('SembastDatabase', () {
    test('throws ArgumentError when rootPath is empty', () {
      expect(
        () => SembastDatabase(
          databaseFactory: databaseFactoryMemory,
          rootPath: '',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('throws ArgumentError when rootPath contains only whitespace', () {
      expect(
        () => SembastDatabase(
          databaseFactory: databaseFactoryMemory,
          rootPath: '   ',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('default construction uses a valid migration configuration', () {
      expect(
        () => SembastDatabase(
          databaseFactory: databaseFactoryMemory,
          rootPath: 'unused',
        ),
        returnsNormally,
      );
    });

    test('memory construction uses an in-memory database', () async {
      // Given
      final database = SembastDatabase.memory();
      expect(database.isOpen, isFalse);

      // When
      final openedDatabase = await database.open();

      // Then
      expect(database.rootPath, 'memory');
      expect(database.path, p.join('memory', DatabaseSchema.fileName));
      expect(openedDatabase.version, DatabaseSchema.version);
      expect(database.isOpen, isTrue);

      await database.close();
    });

    test('starts closed', () {
      final database = SembastDatabase(
        databaseFactory: databaseFactoryMemory,
        rootPath: 'unused',
      );

      expect(database.isOpen, isFalse);
    });

    test('open marks database as open', () async {
      final database = await createTestSembastDatabase();

      await database.open();

      expect(database.isOpen, isTrue);
    });

    test('open returns database with current schema version', () async {
      final database = await createTestSembastDatabase();

      final openedDatabase = await database.open();

      expect(openedDatabase.version, DatabaseSchema.version);
    });

    test(
      'opening passes the schema version and injected migrator callback',
      () async {
        // Given
        final factory = MockDatabaseFactory();
        var migrationRan = false;
        final migrator = DatabaseMigrator(
          supportedVersion: 2,
          migrations: [
            DatabaseMigration(
              fromVersion: 1,
              toVersion: 2,
              operation: (_) async {
                migrationRan = true;
              },
            ),
          ],
        );
        final database = await createTestSembastDatabase(
          databaseFactory: factory,
          migrator: migrator,
        );
        final rawDatabase = await databaseFactoryMemory.openDatabase(
          '${database.path}-result',
          version: DatabaseSchema.version,
        );
        when(
          () => factory.openDatabase(
            any(),
            version: any(named: 'version'),
            onVersionChanged: any(named: 'onVersionChanged'),
            mode: any(named: 'mode'),
          ),
        ).thenAnswer((_) async => rawDatabase);

        // When
        await database.open();

        // Then
        final verification = verify(
          () => factory.openDatabase(
            database.path,
            version: DatabaseSchema.version,
            onVersionChanged: captureAny<OnVersionChangedFunction?>(
              named: 'onVersionChanged',
            ),
            mode: DatabaseMode.create,
          ),
        );
        verification.called(1);
        final capturedCallback = verification.captured.single;
        await capturedCallback(rawDatabase, 1, 2);
        expect(migrationRan, isTrue);
      },
    );

    test('repeated open calls return same database instance', () async {
      final database = await createTestSembastDatabase();

      final first = await database.open();
      final second = await database.open();

      expect(identical(first, second), isTrue);
    });

    test('concurrent open calls return same database instance', () async {
      final database = await createTestSembastDatabase();

      final futures = [database.open(), database.open()];

      final databases = await Future.wait(futures);

      expect(identical(databases[0], databases[1]), isTrue);
      expect(database.isOpen, isTrue);
    });

    test('database getter opens and returns database', () async {
      final database = await createTestSembastDatabase();

      final openedDatabase = await database.database;

      expect(openedDatabase, isNotNull);
      expect(database.isOpen, isTrue);
    });

    test('close marks database as closed', () async {
      final database = await createTestSembastDatabase();

      await database.open();

      await database.close();

      expect(database.isOpen, isFalse);
    });

    test('close is safe when database has not been opened', () async {
      final database = await createTestSembastDatabase();

      await expectLater(database.close(), completes);

      expect(database.isOpen, isFalse);
    });

    test('close is safe when database is already closed', () async {
      final database = await createTestSembastDatabase();

      await database.open();
      await database.close();

      await expectLater(database.close(), completes);

      expect(database.isOpen, isFalse);
    });

    test('database can be reopened after close', () async {
      final database = await createTestSembastDatabase();

      await database.open();
      await database.close();

      expect(database.isOpen, isFalse);

      final reopenedDatabase = await database.open();

      expect(reopenedDatabase, isNotNull);
      expect(database.isOpen, isTrue);
    });

    test('path contains configured database file name', () {
      final database = SembastDatabase(
        databaseFactory: databaseFactoryMemory,
        rootPath: 'database-directory',
      );

      expect(database.path.endsWith(DatabaseSchema.fileName), isTrue);
    });

    test('failed open leaves database closed', () async {
      final expectedError = StateError('open failed');
      final factory = MockDatabaseFactory();
      final database = await createTestSembastDatabase(
        databaseFactory: factory,
      );

      when(
        () => factory.openDatabase(
          any(),
          version: any(named: 'version'),
          onVersionChanged: any(named: 'onVersionChanged'),
          mode: any(named: 'mode'),
        ),
      ).thenThrow(expectedError);

      await expectLater(database.open(), throwsA(same(expectedError)));

      expect(database.isOpen, isFalse);
    });

    test(
      'failed open clears in-flight state so another attempt can be made',
      () async {
        final expectedError = StateError('open failed');
        final factory = MockDatabaseFactory();
        final database = await createTestSembastDatabase(
          databaseFactory: factory,
        );
        var shouldFail = true;

        when(
          () => factory.openDatabase(
            any(),
            version: any(named: 'version'),
            onVersionChanged: any(named: 'onVersionChanged'),
            mode: any(named: 'mode'),
          ),
        ).thenAnswer((_) {
          if (shouldFail) {
            shouldFail = false;
            return Future<Database>.error(expectedError);
          }

          return databaseFactoryMemory.openDatabase(
            database.path,
            version: DatabaseSchema.version,
          );
        });

        await expectLater(database.open(), throwsA(same(expectedError)));

        final reopenedDatabase = await database.open();

        expect(reopenedDatabase.version, DatabaseSchema.version);
        expect(database.isOpen, isTrue);
      },
    );

    test(
      'failed migration leaves database closed and can be retried',
      () async {
        // Given
        final expectedError = StateError('migration failed');
        var shouldFail = true;
        final factory = MockDatabaseFactory();
        final migrator = DatabaseMigrator(
          supportedVersion: 2,
          migrations: [
            DatabaseMigration(
              fromVersion: 1,
              toVersion: 2,
              operation: (_) async {
                if (shouldFail) {
                  shouldFail = false;
                  throw expectedError;
                }
              },
            ),
          ],
        );
        final database = await createTestSembastDatabase(
          databaseFactory: factory,
          migrator: migrator,
        );
        final rawDatabase = await databaseFactoryMemory.openDatabase(
          '${database.path}-result',
          version: DatabaseSchema.version,
        );
        when(
          () => factory.openDatabase(
            any(),
            version: any(named: 'version'),
            onVersionChanged: any(named: 'onVersionChanged'),
            mode: any(named: 'mode'),
          ),
        ).thenAnswer((invocation) async {
          final onVersionChanged = invocation.namedArguments[#onVersionChanged];
          await onVersionChanged(rawDatabase, 1, 2);
          return rawDatabase;
        });

        // When / Then
        await expectLater(database.open(), throwsA(same(expectedError)));
        expect(database.isOpen, isFalse);

        // When
        final retriedDatabase = await database.open();

        // Then
        expect(identical(retriedDatabase, rawDatabase), isTrue);
        expect(database.isOpen, isTrue);
        verify(
          () => factory.openDatabase(
            database.path,
            version: DatabaseSchema.version,
            onVersionChanged: any(named: 'onVersionChanged'),
            mode: DatabaseMode.create,
          ),
        ).called(2);
      },
    );

    test(
      'successful migration stores and reuses the opened database',
      () async {
        // Given
        final factory = MockDatabaseFactory();
        final migrator = DatabaseMigrator(
          supportedVersion: 2,
          migrations: [
            DatabaseMigration(
              fromVersion: 1,
              toVersion: 2,
              operation: (_) async {},
            ),
          ],
        );
        final database = await createTestSembastDatabase(
          databaseFactory: factory,
          migrator: migrator,
        );
        final rawDatabase = await databaseFactoryMemory.openDatabase(
          '${database.path}-result',
          version: DatabaseSchema.version,
        );
        when(
          () => factory.openDatabase(
            any(),
            version: any(named: 'version'),
            onVersionChanged: any(named: 'onVersionChanged'),
            mode: any(named: 'mode'),
          ),
        ).thenAnswer((invocation) async {
          final onVersionChanged = invocation.namedArguments[#onVersionChanged];
          await onVersionChanged(rawDatabase, 1, 2);
          return rawDatabase;
        });

        // When
        final first = await database.open();
        final second = await database.open();

        // Then
        expect(identical(first, rawDatabase), isTrue);
        expect(identical(second, rawDatabase), isTrue);
        expect(database.isOpen, isTrue);
        verify(
          () => factory.openDatabase(
            database.path,
            version: DatabaseSchema.version,
            onVersionChanged: any(named: 'onVersionChanged'),
            mode: DatabaseMode.create,
          ),
        ).called(1);
      },
    );

    test('unsupported downgrade propagates its exception', () async {
      final database = await createTestSembastDatabase();
      final newerDatabase = await databaseFactoryMemory.openDatabase(
        database.path,
        version: DatabaseSchema.version + 1,
      );
      await newerDatabase.close();

      await expectLater(
        database.open(),
        throwsA(isA<UnsupportedDatabaseVersionException>()),
      );
    });

    test('unsupported downgrade leaves database closed', () async {
      final database = await createTestSembastDatabase();
      final newerDatabase = await databaseFactoryMemory.openDatabase(
        database.path,
        version: DatabaseSchema.version + 1,
      );
      await newerDatabase.close();

      await expectLater(
        database.open(),
        throwsA(isA<UnsupportedDatabaseVersionException>()),
      );

      expect(database.isOpen, isFalse);
    });
  });
}
