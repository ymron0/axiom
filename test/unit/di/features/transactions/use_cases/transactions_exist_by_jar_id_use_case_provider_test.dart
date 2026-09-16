@Tags(['application', 'di'])
library;

import 'dart:io';

import 'package:axiom/src/core/di/database_lifecycle_service_provider.dart';
import 'package:axiom/src/core/di/database_root_path_provider.dart';
import 'package:axiom/src/core/identity/ids/jar_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/application/use_cases/transactions_exist_by_jar_id_use_case.dart';
import 'package:axiom/src/features/transactions/di/transaction_repository_provider.dart';
import 'package:axiom/src/features/transactions/di/transactions_exist_by_jar_id_use_case_provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:test/test.dart';

import '../../../../../mocks/transaction_repository_mock.dart';

void main() {
  group('transactionsExistByJarIdUseCase provider', () {
    test('resolves the jar transaction usage use case', () async {
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
      final useCase = container.read(
        transactionsExistByJarIdUseCaseProvider,
      );

      // Then
      expect(useCase, isA<TransactionsExistByJarIdUseCase>());
    });

    test('injects the overridden transaction repository', () async {
      // Given
      final repository = MockTransactionRepository();
      final jarId = JarId.fromString('provider-jar');
      when(() => repository.existsByJarId(jarId)).thenAnswer(
        (_) async => const Success(false),
      );
      final container = ProviderContainer(
        overrides: [
          transactionRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      // When
      final result = await container.read(
        transactionsExistByJarIdUseCaseProvider,
      )(jarId);

      // Then
      expect(result.valueOrNull, isFalse);
      verify(() => repository.existsByJarId(jarId)).called(1);
    });
  });
}

String _uniqueRootPath() {
  return p.join(
    Directory.systemTemp.path,
    'transactions-exist-by-jar-provider-'
    '${DateTime.now().microsecondsSinceEpoch}',
  );
}
