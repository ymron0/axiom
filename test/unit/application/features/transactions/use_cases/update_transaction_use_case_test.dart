import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/application/use_cases/update_transaction_use_case.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_version_conflict_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/transactions/transaction_fixtures.dart';
import '../../../../../mocks/transaction_repository_mock.dart';

void main() {
  group('UpdateTransactionUseCase', () {
    late MockTransactionRepository repository;
    late UpdateTransactionUseCase useCase;

    setUp(() {
      repository = MockTransactionRepository();
      useCase = UpdateTransactionUseCase(repository);
    });

    test('delegates the update to the repository', () async {
      // Given
      final transaction = transactionFixture(id: 'update');
      when(() => repository.update(transaction)).thenAnswer((_) async => const Success(null));

      // When
      final result = await useCase.call(transaction);

      // Then
      expect(result.isSuccess, isTrue);
      verify(() => repository.update(transaction)).called(1);
    });

    test('propagates repository failures', () async {
      // Given
      final transaction = transactionFixture(id: 'conflict');
      const failure = TransactionVersionConflictFailure(message: 'conflict');
      when(() => repository.update(transaction)).thenAnswer((_) async => failure);

      // When
      final result = await useCase.call(transaction);

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
