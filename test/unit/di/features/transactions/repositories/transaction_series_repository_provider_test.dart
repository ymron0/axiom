@Tags(['data', 'di'])
library;

import 'dart:io';

import 'package:axiom/src/core/di/database_lifecycle_service_provider.dart';
import 'package:axiom/src/core/di/database_root_path_provider.dart';
import 'package:axiom/src/features/transactions/data/repositories/sembast_transaction_series_repository_impl.dart';
import 'package:axiom/src/features/transactions/di/transaction_series_repository_provider.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

void main() {
  group('transactionSeriesRepositoryProvider', () {
    test('provides the persistent transaction-series repository', () async {
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
      final repository = container.read(transactionSeriesRepositoryProvider);

      // Then
      expect(repository, isA<SembastTransactionSeriesRepositoryImpl>());
    });
  });
}

String _uniqueRootPath() {
  return p.join(
    Directory.systemTemp.path,
    'transaction-series-repository-provider-'
    '${DateTime.now().microsecondsSinceEpoch}',
  );
}
