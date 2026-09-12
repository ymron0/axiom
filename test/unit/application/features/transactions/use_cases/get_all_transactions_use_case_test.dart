import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/application/use_cases/get_all_transactions_use_case.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_not_found_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/transactions/transaction_fixtures.dart';
import '../../../../../mocks/transaction_repository_mock.dart';

void main() {
  group('GetAllTransactionsUseCase', () {
    late MockTransactionRepository repository;
    late GetAllTransactionsUseCase useCase;

    setUp(() {
      repository = MockTransactionRepository();
      useCase = GetAllTransactionsUseCase(repository);
    });

    test('returns repository transactions', () async {
      // Given
      final transactions = [transactionFixture(id: 'all')];
      when(() => repository.getAll()).thenAnswer((_) async => Success<List<Transaction>>(transactions));

      // When
      final result = await useCase.call();

      // Then
      expect(result.valueOrNull, same(transactions));
      verify(() => repository.getAll()).called(1);
    });

    test('propagates repository failures', () async {
      // Given
      const failure = TransactionNotFoundFailure(message: 'read failed');
      when(() => repository.getAll()).thenAnswer((_) async => failure);

      // When
      final result = await useCase.call();

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
