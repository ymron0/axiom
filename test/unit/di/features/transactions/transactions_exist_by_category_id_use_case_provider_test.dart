import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/application/use_cases/transactions_exist_by_category_id_use_case.dart';
import 'package:axiom/src/features/transactions/di/transaction_repository_provider.dart';
import 'package:axiom/src/features/transactions/di/transactions_exist_by_category_id_use_case_provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:test/test.dart';

import '../../../../mocks/transaction_repository_mock.dart';

void main() {
  group('transactionsExistByCategoryIdUseCase provider', () {
    test('resolves the category transaction usage use case', () {
      // Given
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // When
      final useCase = container.read(
        transactionsExistByCategoryIdUseCaseProvider,
      );

      // Then
      expect(useCase, isA<TransactionsExistByCategoryIdUseCase>());
    });

    test('injects the overridden transaction repository', () async {
      // Given
      final repository = MockTransactionRepository();
      final categoryId = CategoryId.fromString('groceries');
      when(
        () => repository.existsByCategoryId(categoryId),
      ).thenAnswer((_) async => const Success(false));
      final container = ProviderContainer(
        overrides: [
          transactionRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      // When
      final result = await container.read(
        transactionsExistByCategoryIdUseCaseProvider,
      )(categoryId);

      // Then
      expect(result.valueOrNull, isFalse);
      verify(() => repository.existsByCategoryId(categoryId)).called(1);
    });
  });
}
