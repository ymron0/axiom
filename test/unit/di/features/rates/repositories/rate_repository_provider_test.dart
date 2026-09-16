@Tags(['data', 'di'])
library;

import 'dart:io';

import 'package:axiom/src/core/di/database_lifecycle_service_provider.dart';
import 'package:axiom/src/core/di/database_root_path_provider.dart';
import 'package:axiom/src/features/rates/data/repositories/sembast_rate_repository_impl.dart';
import 'package:axiom/src/features/rates/di/rate_repository_provider.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:test/test.dart';

void main() {
  group('rateRepositoryProvider', () {
    test('provides the persistent rate repository', () async {
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

      final repository = container.read(rateRepositoryProvider);

      expect(repository, isA<SembastRateRepositoryImpl>());
    });
  });
}

String _uniqueRootPath() {
  return p.join(
    Directory.systemTemp.path,
    'rate-repository-provider-'
    '${DateTime.now().microsecondsSinceEpoch}',
  );
}
