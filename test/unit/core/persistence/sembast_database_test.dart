@Tags(['core', 'persistence'])
library;

import 'dart:io';

import 'package:axiom/src/core/persistence/database_schema.dart';
import 'package:axiom/src/core/persistence/sembast_database.dart';
import 'package:axiom/src/core/persistence/unsupported_database_version_exception.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

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

    test('starts closed', () {
      final database = SembastDatabase(
        databaseFactory: databaseFactoryMemory,
        rootPath: 'unused',
      );

      expect(database.isOpen, isFalse);
    });

    test('open marks database as open', () async {
      final database = await _createTestDatabase();

      await database.open();

      expect(database.isOpen, isTrue);
    });

    test('open returns database with current schema version', () async {
      final database = await _createTestDatabase();

      final openedDatabase = await database.open();

      expect(openedDatabase.version, DatabaseSchema.version);
    });

    test('repeated open calls return same database instance', () async {
      final database = await _createTestDatabase();

      final first = await database.open();
      final second = await database.open();

      expect(identical(first, second), isTrue);
    });

    test('concurrent open calls return same database instance', () async {
      final database = await _createTestDatabase();

      final futures = [database.open(), database.open()];

      final databases = await Future.wait(futures);

      expect(identical(databases[0], databases[1]), isTrue);
      expect(database.isOpen, isTrue);
    });

    test('database getter opens and returns database', () async {
      final database = await _createTestDatabase();

      final openedDatabase = await database.database;

      expect(openedDatabase, isNotNull);
      expect(database.isOpen, isTrue);
    });

    test('close marks database as closed', () async {
      final database = await _createTestDatabase();

      await database.open();

      await database.close();

      expect(database.isOpen, isFalse);
    });

    test('close is safe when database has not been opened', () async {
      final database = await _createTestDatabase();

      await expectLater(database.close(), completes);

      expect(database.isOpen, isFalse);
    });

    test('close is safe when database is already closed', () async {
      final database = await _createTestDatabase();

      await database.open();
      await database.close();

      await expectLater(database.close(), completes);

      expect(database.isOpen, isFalse);
    });

    test('database can be reopened after close', () async {
      final database = await _createTestDatabase();

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
      final database = await _createTestDatabase(databaseFactory: factory);

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
        final database = await _createTestDatabase(databaseFactory: factory);
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

    test('unsupported downgrade propagates its exception', () async {
      final database = await _createTestDatabase();
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
      final database = await _createTestDatabase();
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

Future<SembastDatabase> _createTestDatabase({
  DatabaseFactory? databaseFactory,
}) async {
  final rootDirectory = await Directory.systemTemp.createTemp(
    'sembast-database-test-',
  );

  final database = SembastDatabase(
    databaseFactory: databaseFactory ?? databaseFactoryMemory,
    rootPath: rootDirectory.path,
  );

  addTearDown(() async {
    await database.close();

    if (await rootDirectory.exists()) {
      await rootDirectory.delete(recursive: true);
    }
  });

  return database;
}
