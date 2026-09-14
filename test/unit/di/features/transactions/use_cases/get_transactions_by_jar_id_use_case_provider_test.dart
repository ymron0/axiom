@Tags(['di'])
library;

import 'package:axiom/src/core/identity/ids/jar_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/application/use_cases/get_transactions_by_jar_id_use_case.dart';
import 'package:axiom/src/features/transactions/di/get_transactions_by_jar_id_use_case_provider.dart';
import 'package:axiom/src/features/transactions/di/transaction_repository_provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:test/test.dart';

import '../../../../../mocks/transaction_repository_mock.dart';

void main() {
  group('getTransactionsByJarIdUseCase provider', () {
    test('resolves the use case and injects the repository', () async {
      final repository = MockTransactionRepository();
      final jarId = JarId.fromString('jar-1');
      when(() => repository.getTransactionsByJarId(jarId)).thenAnswer(
        (_) async => const Success([]),
      );
      final container = ProviderContainer(overrides: [
        transactionRepositoryProvider.overrideWithValue(repository),
      ]);
      addTearDown(container.dispose);

      final useCase = container.read(getTransactionsByJarIdUseCaseProvider);
      final result = await useCase(jarId);

      expect(useCase, isA<GetTransactionsByJarIdUseCase>());
      expect(result.valueOrNull, isEmpty);
      verify(() => repository.getTransactionsByJarId(jarId)).called(1);
    });
  });
}
