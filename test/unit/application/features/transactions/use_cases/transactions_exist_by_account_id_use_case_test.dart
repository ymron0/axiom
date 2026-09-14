@Tags(['application'])
library;

import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/application/use_cases/transactions_exist_by_account_id_use_case.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_not_found_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../mocks/transaction_repository_mock.dart';

void main() {
  group('TransactionsExistByAccountIdUseCase', () {
    late MockTransactionRepository repository;
    late TransactionsExistByAccountIdUseCase useCase;

    setUp(() {
      repository = MockTransactionRepository();
      useCase = TransactionsExistByAccountIdUseCase(repository);
    });

    test('returns whether persisted transactions affect the account', () async {
      // Given
      final accountId = AccountId.fromString('account-in-use');
      when(
        () => repository.existsByAccountId(accountId),
      ).thenAnswer((_) async => const Success(true));

      // When
      final result = await useCase(accountId);

      // Then
      expect(result.valueOrNull, isTrue);
      verify(() => repository.existsByAccountId(accountId)).called(1);
    });

    test('propagates repository failures', () async {
      // Given
      final accountId = AccountId.fromString('lookup-failure');
      const failure = TransactionNotFoundFailure(message: 'lookup failed');
      when(
        () => repository.existsByAccountId(accountId),
      ).thenAnswer((_) async => failure);

      // When
      final result = await useCase(accountId);

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
