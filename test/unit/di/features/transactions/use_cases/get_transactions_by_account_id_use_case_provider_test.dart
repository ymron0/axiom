@Tags(['di'])
library;

import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/application/use_cases/get_transactions_by_account_id_use_case.dart';
import 'package:axiom/src/features/transactions/di/get_transactions_by_account_id_use_case_provider.dart';
import 'package:axiom/src/features/transactions/di/transaction_repository_provider.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:test/test.dart';

import '../../../../../mocks/transaction_repository_mock.dart';

void main() {
  group('getTransactionsByAccountIdUseCase provider', () {
    test('resolves the use case and injects the repository', () async {
      // Given
      final repository = MockTransactionRepository();
      final accountId = AccountId.fromString('account-1');
      when(
        () => repository.getTransactionsByAccountId(accountId),
      ).thenAnswer((_) async => const Success<List<Transaction>>([]));
      final container = ProviderContainer(
        overrides: [
          transactionRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      // When
      final useCase = container.read(getTransactionsByAccountIdUseCaseProvider);
      final result = await useCase(accountId);

      // Then
      expect(useCase, isA<GetTransactionsByAccountIdUseCase>());
      expect(result.valueOrNull, isEmpty);
      verify(() => repository.getTransactionsByAccountId(accountId)).called(1);
    });
  });
}
