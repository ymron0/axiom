@Tags(['application'])
library;

import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/application/use_cases/transaction_series_exist_by_account_id_use_case.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/transactions/transaction_series_failure_fixture.dart';
import '../../../../../mocks/transaction_series_repository_mock.dart';

void main() {
  group('TransactionSeriesExistByAccountIdUseCase', () {
    late MockTransactionSeriesRepository repository;
    late TransactionSeriesExistByAccountIdUseCase useCase;

    setUp(() {
      repository = MockTransactionSeriesRepository();
      useCase = TransactionSeriesExistByAccountIdUseCase(
        repository: repository,
      );
    });

    test(
      'returns whether a transaction series references the account',
      () async {
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
      },
    );

    test('propagates repository failures', () async {
      // Given
      final accountId = AccountId.fromString('account-failure');
      const failure = TestTransactionSeriesFailure(message: 'lookup failed');

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
