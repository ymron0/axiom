import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/application/use_cases/query_transactions_use_case.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_not_found_failure.dart';
import 'package:axiom/src/features/transactions/domain/repositories/transaction_query.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/transactions/transaction_fixtures.dart';
import '../../../../../mocks/transaction_repository_mock.dart';

void main() {
  group('QueryTransactionsUseCase', () {
    late MockTransactionRepository repository;
    late QueryTransactionsUseCase useCase;

    setUp(() {
      repository = MockTransactionRepository();
      useCase = QueryTransactionsUseCase(repository);
    });

    test('returns repository query results', () async {
      // Given
      final query = TransactionQuery();
      final transactions = [transactionFixture(id: 'query')];
      when(
        () => repository.query(query),
      ).thenAnswer((_) async => Success<List<Transaction>>(transactions));

      // When
      final result = await useCase.call(query);

      // Then
      expect(result.valueOrNull, same(transactions));
      verify(() => repository.query(query)).called(1);
    });

    test('forwards effective-time criteria to the repository', () async {
      // Given
      final query = TransactionQuery(
        effectiveFrom: DateTime.utc(2026, 1, 1),
        effectiveUntil: DateTime.utc(2026, 2, 1),
      );
      when(
        () => repository.query(query),
      ).thenAnswer((_) async => const Success([]));

      // When
      await useCase.call(query);

      // Then
      verify(() => repository.query(query)).called(1);
    });

    test('propagates repository failures', () async {
      // Given
      final query = TransactionQuery();
      const failure = TransactionNotFoundFailure(message: 'query failed');
      when(() => repository.query(query)).thenAnswer((_) async => failure);

      // When
      final result = await useCase.call(query);

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
