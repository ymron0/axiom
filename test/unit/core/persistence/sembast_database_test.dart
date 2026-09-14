@Tags(['core', 'persistence'])
library;

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
        rootPath: 'test',
      );

      expect(database.isOpen, isFalse);
    });

    test('open marks database as open', () async {
      final database = SembastDatabase(
        databaseFactory: databaseFactoryMemory,
        rootPath: 'test',
      );

      try {
        await database.open();

        expect(database.isOpen, isTrue);
      } finally {
        await database.close();
      }
    });

    test('open returns database with current schema version', () async {
      final database = SembastDatabase(
        databaseFactory: databaseFactoryMemory,
        rootPath: 'test-version',
      );

      try {
        final openedDatabase = await database.open();

        expect(openedDatabase.version, DatabaseSchema.version);
      } finally {
        await database.close();
      }
    });

    test('repeated open calls return same database instance', () async {
      final database = SembastDatabase(
        databaseFactory: databaseFactoryMemory,
        rootPath: 'test-same-instance',
      );

      try {
        final first = await database.open();
        final second = await database.open();

        expect(identical(first, second), isTrue);
      } finally {
        await database.close();
      }
    });

    test('database getter opens and returns database', () async {
      final database = SembastDatabase(
        databaseFactory: databaseFactoryMemory,
        rootPath: 'test-getter',
      );

      try {
        final openedDatabase = await database.database;

        expect(openedDatabase, isNotNull);
        expect(database.isOpen, isTrue);
      } finally {
        await database.close();
      }
    });

    test('close marks database as closed', () async {
      final database = SembastDatabase(
        databaseFactory: databaseFactoryMemory,
        rootPath: 'test-close',
      );

      await database.open();
      await database.close();

      expect(database.isOpen, isFalse);
    });

    test('close is safe when database has not been opened', () async {
      final database = SembastDatabase(
        databaseFactory: databaseFactoryMemory,
        rootPath: 'test-close-unopened',
      );

      await expectLater(database.close(), completes);

      expect(database.isOpen, isFalse);
    });

    test('database can be reopened after close', () async {
      final database = SembastDatabase(
        databaseFactory: databaseFactoryMemory,
        rootPath: 'test-reopen',
      );

      final first = await database.open();

      await database.close();

      final second = await database.open();

      try {
        expect(identical(first, second), isTrue);

        expect(database.isOpen, isTrue);
      } finally {
        await database.close();
      }
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
