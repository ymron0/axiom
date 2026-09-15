@Tags(['di'])
library;

import 'package:axiom/src/core/di/database_root_path_provider.dart';
import 'package:riverpod/riverpod.dart';
import 'package:riverpod/misc.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:test/test.dart';

void main() {
  group('databaseRootPathProvider', () {
    test('throws when read without an override', () {
      // Given
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // When / Then
      expect(
        () => container.read(databaseRootPathProvider),
        throwsA(predicate<ProviderException>(_isMissingRootPathError)),
      );
    });

    test('returns the overridden root path exactly', () {
      // Given
      const path = r'D:\axiom-data\database';
      final container = ProviderContainer(
        overrides: [databaseRootPathProvider.overrideWithValue(path)],
      );
      addTearDown(container.dispose);

      // When
      final result = container.read(databaseRootPathProvider);

      // Then
      expect(result, path);
    });

    test('returns the configured value on repeated reads', () {
      // Given
      const path = r'D:\axiom-data\database';
      final container = ProviderContainer(
        overrides: [databaseRootPathProvider.overrideWithValue(path)],
      );
      addTearDown(container.dispose);

      // When
      final firstRead = container.read(databaseRootPathProvider);
      final secondRead = container.read(databaseRootPathProvider);

      // Then
      expect(firstRead, path);
      expect(secondRead, path);
    });

    test('allows different containers to provide different root paths', () {
      // Given
      const firstPath = r'D:\axiom-data\first-database';
      const secondPath = r'D:\axiom-data\second-database';
      final firstContainer = ProviderContainer(
        overrides: [databaseRootPathProvider.overrideWithValue(firstPath)],
      );
      final secondContainer = ProviderContainer(
        overrides: [databaseRootPathProvider.overrideWithValue(secondPath)],
      );
      addTearDown(firstContainer.dispose);
      addTearDown(secondContainer.dispose);

      // When
      final firstResult = firstContainer.read(databaseRootPathProvider);
      final secondResult = secondContainer.read(databaseRootPathProvider);

      // Then
      expect(firstResult, firstPath);
      expect(secondResult, secondPath);
    });
  });
}

bool _isMissingRootPathError(ProviderException error) {
  Object cause = error;

  while (cause is ProviderException) {
    cause = cause.exception;
  }

  return cause is StateError &&
      cause.message ==
          'databaseRootPathProvider must be overridden during application '
              'bootstrap.';
}
