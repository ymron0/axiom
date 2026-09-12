import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/application/use_cases/create_all_transactions_use_case.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_already_exists_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/transactions/transaction_fixtures.dart';
import '../../../../../mocks/transaction_repository_mock.dart';

void main() {
  group('CreateAllTransactionsUseCase', () {
    late MockTransactionRepository repository;
    late CreateAllTransactionsUseCase useCase;

    setUp(() {
      repository = MockTransactionRepository();
      useCase = CreateAllTransactionsUseCase(repository);
    });

    test('delegates the batch to the repository', () async {
      // Given
      final transactions = [transactionFixture(id: 'first'), transactionFixture(id: 'second')];
      when(() => repository.createAll(transactions)).thenAnswer((_) async => const Success(null));

      // When
      final result = await useCase.call(transactions);

      // Then
      expect(result.isSuccess, isTrue);
      verify(() => repository.createAll(transactions)).called(1);
    });

    test('propagates repository failures', () async {
      // Given
      final transactions = [transactionFixture(id: 'duplicate')];
      const failure = TransactionAlreadyExistsFailure(message: 'duplicate');
      when(() => repository.createAll(transactions)).thenAnswer((_) async => failure);

      // When
      final result = await useCase.call(transactions);

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
