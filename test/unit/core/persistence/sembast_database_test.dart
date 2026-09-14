@Tags(['core', 'persistence'])
library;

import 'dart:io';

import 'package:axiom/src/core/persistence/database_schema.dart';
import 'package:axiom/src/core/persistence/sembast_database.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:test/test.dart';

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

      final futures = [
        database.open(),
        database.open(),
      ];

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
  });
}

Future<SembastDatabase> _createTestDatabase() async {
  final rootDirectory = await Directory.systemTemp.createTemp(
    'sembast-database-test-',
  );

  final database = SembastDatabase(
    databaseFactory: databaseFactoryMemory,
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