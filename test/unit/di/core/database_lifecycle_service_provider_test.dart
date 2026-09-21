@Tags(['di'])
library;

import 'dart:io';

import 'package:axiom/src/core/di/database_lifecycle_service_provider.dart';
import 'package:axiom/src/core/di/database_root_path_provider.dart';
import 'package:axiom/src/core/di/sembast_database_provider.dart';
import 'package:axiom/src/core/persistence/database_lifecycle_service.dart';
import 'package:axiom/src/core/persistence/database_schema.dart';
import 'package:axiom/src/core/persistence/sembast_database.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod/riverpod.dart';
import 'package:riverpod/misc.dart';
import 'package:test/test.dart';

void main() {
  group('databaseLifecycleServiceProvider', () {
    test('resolves a DatabaseLifecycleService with a root-path override', () {
      // Given
      final container = _createContainer(rootPath: _uniqueRootPath());
      addTearDown(container.dispose);

      // When
      final service = container.read(databaseLifecycleServiceProvider);

      // Then
      expect(service, isA<DatabaseLifecycleService>());
    });

    test('returns the same lifecycle-service instance on repeated reads', () {
      // Given
      final container = _createContainer(rootPath: _uniqueRootPath());
      addTearDown(container.dispose);

      // When
      final firstRead = container.read(databaseLifecycleServiceProvider);
      final secondRead = container.read(databaseLifecycleServiceProvider);

      // Then
      expect(identical(firstRead, secondRead), isTrue);
    });

    test(
      'starts closed without creating or opening database contents',
      () async {
        // Given
        final rootPath = _uniqueRootPath();
        final rootDirectory = Directory(rootPath);
        final databaseFile = File(p.join(rootPath, DatabaseSchema.fileName));
        final container = _createContainer(rootPath: rootPath);
        addTearDown(container.dispose);
        addTearDown(() async {
          if (await rootDirectory.exists()) {
            await rootDirectory.delete(recursive: true);
          }
        });

        // When
        final service = container.read(databaseLifecycleServiceProvider);
        final database = container.read(sembastDatabaseProvider);

        // Then
        expect(service.isOpen, isFalse);
        expect(database.isOpen, isFalse);
        expect(await rootDirectory.exists(), isFalse);
        expect(await databaseFile.exists(), isFalse);
      },
    );

    test('propagates missing root-path configuration', () {
      // Given
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // When / Then
      expect(
        () => container.read(databaseLifecycleServiceProvider),
        throwsA(predicate<ProviderException>(_isMissingRootPathError)),
      );
    });

    test(
      'uses the SembastDatabase supplied by sembastDatabaseProvider',
      () async {
        // Given
        final rootPath = _uniqueRootPath();
        final rootDirectory = Directory(rootPath);
        final container = _createContainer(rootPath: rootPath);
        addTearDown(container.dispose);
        final database = container.read(sembastDatabaseProvider);
        final service = container.read(databaseLifecycleServiceProvider);
        addTearDown(() async {
          await service.close();
          if (await rootDirectory.exists()) {
            await rootDirectory.delete(recursive: true);
          }
        });
        final expectedDatabase = await database.open();

        // When
        final result = await service.open();

        // Then
        expect(database, isA<SembastDatabase>());
        expect(result.valueOrNull, same(expectedDatabase));
      },
    );
  });
}

ProviderContainer _createContainer({required String rootPath}) {
  return ProviderContainer(
    overrides: [databaseRootPathProvider.overrideWithValue(rootPath)],
  );
}

String _uniqueRootPath() {
  return p.join(
    Directory.systemTemp.path,
    'test-database-lifecycle-service-provider-${DateTime.now().microsecondsSinceEpoch}',
  );
}

bool _isMissingRootPathError(ProviderException error) {
  Object cause = error;

  while (cause is ProviderException) {
    cause = cause.exception;
  }

  if (cause is! StateError) {
    return false;
  }

  return cause.message ==
      'databaseRootPathProvider must be overridden during application '
          'bootstrap.';
}
