@Tags(['application', 'di'])
library;

import 'package:axiom/src/core/identity/ids/tag_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/application/use_cases/get_transactions_by_tag_id_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/transactions_exist_by_tag_id_use_case.dart';
import 'package:axiom/src/features/transactions/di/get_transactions_by_tag_id_use_case_provider.dart';
import 'package:axiom/src/features/transactions/di/transaction_repository_provider.dart';
import 'package:axiom/src/features/transactions/di/transactions_exist_by_tag_id_use_case_provider.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/transactions/transaction_fixtures.dart';
import '../../../../../mocks/transaction_repository_mock.dart';

void main() {
  group('transaction tag-query use-case providers', () {
    test('resolve and use the overridden transaction repository', () async {
      // Given
      final repository = MockTransactionRepository();

      final tagId = TagId.fromString('provider-tag');

      final transaction = transactionFixture(
        id: 'provider-tagged-transaction',
        tagIds: [tagId],
      );

      when(
        () => repository.getTransactionsByTagId(tagId),
      ).thenAnswer(
        (_) async => Success<List<Transaction>>([transaction]),
      );

      when(
        () => repository.existsByTagId(tagId),
      ).thenAnswer(
        (_) async => const Success(true),
      );

      final container = ProviderContainer(
        overrides: [
          transactionRepositoryProvider.overrideWithValue(repository),
        ],
      );

      addTearDown(container.dispose);

      // When
      final getTransactions = container.read(
        getTransactionsByTagIdUseCaseProvider,
      );

      final transactionsExist = container.read(
        transactionsExistByTagIdUseCaseProvider,
      );

      final transactionsResult = await getTransactions(tagId);
      final existsResult = await transactionsExist(tagId);

      // Then
      expect(
        getTransactions,
        isA<GetTransactionsByTagIdUseCase>(),
      );

      expect(
        transactionsExist,
        isA<TransactionsExistByTagIdUseCase>(),
      );

      expect(
        transactionsResult.valueOrNull,
        [transaction],
      );

      expect(
        existsResult.valueOrNull,
        isTrue,
      );

      verify(
        () => repository.getTransactionsByTagId(tagId),
      ).called(1);

      verify(
        () => repository.existsByTagId(tagId),
      ).called(1);
    });
  });
}