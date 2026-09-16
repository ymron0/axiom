@Tags(['data', 'di'])
library;

import 'dart:io';

import 'package:axiom/src/core/di/database_lifecycle_service_provider.dart';
import 'package:axiom/src/core/di/database_root_path_provider.dart';
import 'package:axiom/src/features/settings/data/repositories/sembast_settings_repository_impl.dart';
import 'package:axiom/src/features/settings/di/settings_repository_provider.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:test/test.dart';

void main() {
  group('settingsRepositoryProvider', () {
    test('provides the persistent settings repository', () async {
      // Given
      final rootPath = _uniqueRootPath();
      final rootDirectory = Directory(rootPath);
      final container = ProviderContainer(
        overrides: [databaseRootPathProvider.overrideWithValue(rootPath)],
      );
      final lifecycleService = container.read(databaseLifecycleServiceProvider);
      addTearDown(() async {
        await lifecycleService.close();
        container.dispose();
        if (await rootDirectory.exists()) {
          await rootDirectory.delete(recursive: true);
        }
      });
      expect((await lifecycleService.open()).isSuccess, isTrue);

      // When
      final repository = container.read(settingsRepositoryProvider);

      // Then
      expect(repository, isA<SembastSettingsRepositoryImpl>());
    });
  });
}

String _uniqueRootPath() {
  return p.join(
    Directory.systemTemp.path,
    'settings-repository-provider-'
    '${DateTime.now().microsecondsSinceEpoch}',
  );
}
