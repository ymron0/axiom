@Tags(['application'])
library;

import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/application/use_cases/delete_transaction_series_use_case.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction_series.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/transactions/transaction_series_failure_fixture.dart';
import '../../../../../fixtures/features/transactions/transaction_series_fixtures.dart';
import '../../../../../mocks/transaction_series_repository_mock.dart';

void main() {
  group('DeleteTransactionSeriesUseCase', () {
    late MockTransactionSeriesRepository repository;
    late DeleteTransactionSeriesUseCase useCase;

    setUp(() {
      repository = MockTransactionSeriesRepository();
      useCase = DeleteTransactionSeriesUseCase(repository: repository);
    });

    test('returns the repository deleted snapshot', () async {
      // Given
      final deleted = transactionSeriesFixture(
        id: 'delete-series',
        deletedAt: DateTime.utc(2026, 2, 1),
      );

      when(
        () => repository.delete(deleted.id),
      ).thenAnswer((_) async => Success<TransactionSeries>(deleted));

      // When
      final result = await useCase(deleted.id);

      // Then
      expect(result.valueOrNull, same(deleted));
      verify(() => repository.delete(deleted.id)).called(1);
    });

    test('propagates repository failures', () async {
      // Given
      final id = transactionSeriesFixture(id: 'delete-failure').id;
      const failure = TestTransactionSeriesFailure(message: 'delete failed');

      when(
        () => repository.delete(id),
      ).thenAnswer((_) async => failure);

      // When
      final result = await useCase(id);

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}