@Tags(['di'])
library;

import 'dart:io';

import 'package:axiom/src/core/di/database_root_path_provider.dart';
import 'package:axiom/src/core/di/database_storage_mode_provider.dart';
import 'package:axiom/src/core/di/sembast_database_provider.dart';
import 'package:axiom/src/core/persistence/database_schema.dart';
import 'package:axiom/src/core/persistence/database_storage_mode.dart';
import 'package:axiom/src/core/persistence/sembast_database.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:test/test.dart';

void main() {
  group('sembastDatabaseProvider', () {
    test('resolves a SembastDatabase that is closed initially', () {
      // Given
      final container = _createContainer(rootPath: _uniqueRootPath());
      addTearDown(container.dispose);

      // When
      final database = container.read(sembastDatabaseProvider);

      // Then
      expect(database, isA<SembastDatabase>());
      expect(database.isOpen, isFalse);
    });

    test('uses the configured root path and database file name', () {
      // Given
      final rootPath = _uniqueRootPath();
      final container = _createContainer(rootPath: rootPath);
      addTearDown(container.dispose);

      // When
      final database = container.read(sembastDatabaseProvider);

      // Then
      expect(database.rootPath, rootPath);
      expect(database.path, p.join(rootPath, DatabaseSchema.fileName));
    });

    test('constructs an in-memory database for memory storage mode', () {
      // Given
      final container = ProviderContainer(
        overrides: [
          databaseStorageModeProvider.overrideWithValue(
            DatabaseStorageMode.memory,
          ),
        ],
      );
      addTearDown(container.dispose);

      // When
      final database = container.read(sembastDatabaseProvider);

      // Then
      expect(database, isA<SembastDatabase>());
      expect(database.rootPath, 'memory');
      expect(database.isOpen, isFalse);
    });

    test('returns the same instance on repeated reads', () {
      // Given
      final container = _createContainer(rootPath: _uniqueRootPath());
      addTearDown(container.dispose);

      // When
      final firstRead = container.read(sembastDatabaseProvider);
      final secondRead = container.read(sembastDatabaseProvider);

      // Then
      expect(identical(firstRead, secondRead), isTrue);
    });

    test('uses the overridden root path when constructing the database', () {
      // Given
      final firstRootPath = _uniqueRootPath();
      final secondRootPath = _uniqueRootPath();
      final firstContainer = _createContainer(rootPath: firstRootPath);
      final secondContainer = _createContainer(rootPath: secondRootPath);
      addTearDown(firstContainer.dispose);
      addTearDown(secondContainer.dispose);

      // When
      final firstDatabase = firstContainer.read(sembastDatabaseProvider);
      final secondDatabase = secondContainer.read(sembastDatabaseProvider);

      // Then
      expect(
        firstDatabase.path,
        p.join(firstRootPath, DatabaseSchema.fileName),
      );
      expect(
        secondDatabase.path,
        p.join(secondRootPath, DatabaseSchema.fileName),
      );
      expect(firstDatabase.path, isNot(secondDatabase.path));
    });

    test('does not create or mutate database contents when resolved', () {
      // Given
      final rootPath = _uniqueRootPath();
      final rootDirectory = Directory(rootPath);
      final databaseFile = File(p.join(rootPath, DatabaseSchema.fileName));
      final container = _createContainer(rootPath: rootPath);
      addTearDown(container.dispose);
      addTearDown(() async {
        if (rootDirectory.existsSync()) {
          await rootDirectory.delete(recursive: true);
        }
      });

      // When
      final database = container.read(sembastDatabaseProvider);

      // Then
      expect(database.isOpen, isFalse);
      expect(rootDirectory.existsSync(), isFalse);
      expect(databaseFile.existsSync(), isFalse);
    });
  });
}

ProviderContainer _createContainer({required String rootPath}) {
  return ProviderContainer(
    overrides: [databaseRootPathProvider.overrideWithValue(rootPath)],
  );
}

int _rootPathCounter = 0;

String _uniqueRootPath() {
  _rootPathCounter++;

  return p.join(
    Directory.systemTemp.path,
    'axiom-sembast-database-provider-${DateTime.now().microsecondsSinceEpoch}-$_rootPathCounter',
  );
}
