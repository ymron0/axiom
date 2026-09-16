@Tags(['di', 'persistence'])
library;

import 'dart:io';

import 'package:axiom/src/core/di/database_lifecycle_service_provider.dart';
import 'package:axiom/src/core/di/database_root_path_provider.dart';
import 'package:axiom/src/core/di/validated_database_provider.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod/misc.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

void main() {
  group('validatedDatabaseProvider', () {
    test('throws when the database lifecycle has not been opened', () {
      // Given
      final rootPath = _uniqueRootPath();
      final container = _createContainer(rootPath: rootPath);

      addTearDown(container.dispose);

      // When / Then
      expect(
        () => container.read(validatedDatabaseProvider),
        throwsA(predicate<ProviderException>(_isDatabaseNotOpenError)),
      );
    });

    test('returns the database published by the lifecycle service', () async {
      // Given
      final rootPath = _uniqueRootPath();
      final rootDirectory = Directory(rootPath);
      final container = _createContainer(rootPath: rootPath);

      addTearDown(container.dispose);

      final lifecycleService = container.read(databaseLifecycleServiceProvider);

      addTearDown(() async {
        await lifecycleService.close();

        if (await rootDirectory.exists()) {
          await rootDirectory.delete(recursive: true);
        }
      });

      final openResult = await lifecycleService.open();

      expect(openResult.isSuccess, isTrue);

      final expectedDatabase = openResult.valueOrNull;

      expect(expectedDatabase, isNotNull);

      // When
      final actualDatabase = container.read(validatedDatabaseProvider);

      // Then
      expect(actualDatabase, same(expectedDatabase));
    });

    test('returns the same database on repeated reads', () async {
      // Given
      final rootPath = _uniqueRootPath();
      final rootDirectory = Directory(rootPath);
      final container = _createContainer(rootPath: rootPath);

      addTearDown(container.dispose);

      final lifecycleService = container.read(databaseLifecycleServiceProvider);

      addTearDown(() async {
        await lifecycleService.close();

        if (await rootDirectory.exists()) {
          await rootDirectory.delete(recursive: true);
        }
      });

      final openResult = await lifecycleService.open();

      expect(openResult.isSuccess, isTrue);

      // When
      final firstRead = container.read(validatedDatabaseProvider);
      final secondRead = container.read(validatedDatabaseProvider);

      // Then
      expect(secondRead, same(firstRead));
    });
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
    'validated-database-provider-'
    '${DateTime.now().microsecondsSinceEpoch}',
  );
}

bool _isDatabaseNotOpenError(ProviderException error) {
  Object cause = error;

  while (cause is ProviderException) {
    cause = cause.exception;
  }

  if (cause is! StateError) {
    return false;
  }

  return cause.message ==
      'validatedDatabaseProvider requires the database lifecycle to be '
          'opened successfully before persistent repositories are resolved.';
}
