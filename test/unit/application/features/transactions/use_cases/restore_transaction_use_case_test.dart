import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/application/use_cases/restore_transaction_use_case.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_already_exists_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/transactions/transaction_fixtures.dart';
import '../../../../../mocks/transaction_repository_mock.dart';

void main() {
  group('RestoreTransactionUseCase', () {
    late MockTransactionRepository repository;
    late RestoreTransactionUseCase useCase;

    setUp(() {
      repository = MockTransactionRepository();
      useCase = RestoreTransactionUseCase(repository);
    });

    test('delegates the deleted snapshot to the repository', () async {
      // Given
      final transaction = transactionFixture(id: 'restore', deletedAt: DateTime.utc(2026, 1, 2));
      when(() => repository.restore(transaction)).thenAnswer((_) async => const Success(null));

      // When
      final result = await useCase.call(transaction);

      // Then
      expect(result.isSuccess, isTrue);
      verify(() => repository.restore(transaction)).called(1);
    });

    test('propagates repository failures', () async {
      // Given
      final transaction = transactionFixture(id: 'existing', deletedAt: DateTime.utc(2026, 1, 2));
      const failure = TransactionAlreadyExistsFailure(message: 'existing');
      when(() => repository.restore(transaction)).thenAnswer((_) async => failure);

      // When
      final result = await useCase.call(transaction);

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
