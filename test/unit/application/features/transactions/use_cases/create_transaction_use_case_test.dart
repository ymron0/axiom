import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/application/use_cases/create_transaction_use_case.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_already_exists_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/transactions/transaction_fixtures.dart';
import '../../../../../mocks/transaction_repository_mock.dart';

void main() {
  group('CreateTransactionUseCase', () {
    late MockTransactionRepository repository;
    late CreateTransactionUseCase useCase;

    setUp(() {
      repository = MockTransactionRepository();
      useCase = CreateTransactionUseCase(repository);
    });

    test('delegates creation to the repository', () async {
      // Given
      final transaction = transactionFixture(id: 'create');
      when(() => repository.create(transaction)).thenAnswer((_) async => const Success(null));

      // When
      final result = await useCase.call(transaction);

      // Then
      expect(result.isSuccess, isTrue);
      verify(() => repository.create(transaction)).called(1);
    });

    test('propagates repository failures', () async {
      // Given
      final transaction = transactionFixture(id: 'duplicate');
      const failure = TransactionAlreadyExistsFailure(message: 'duplicate');
      when(() => repository.create(transaction)).thenAnswer((_) async => failure);

      // When
      final result = await useCase.call(transaction);

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
