@Tags(['application'])
library;

import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/application/use_cases/get_transaction_series_use_case.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction_series.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/transactions/transaction_series_failure_fixture.dart';
import '../../../../../fixtures/features/transactions/transaction_series_fixtures.dart';
import '../../../../../mocks/transaction_series_repository_mock.dart';

void main() {
  group('GetTransactionSeriesUseCase', () {
    late MockTransactionSeriesRepository repository;
    late GetTransactionSeriesUseCase useCase;

    setUp(() {
      repository = MockTransactionSeriesRepository();
      useCase = GetTransactionSeriesUseCase(repository: repository);
    });

    test('returns all persisted transaction series', () async {
      // Given
      final series = <TransactionSeries>[
        transactionSeriesFixture(id: 'series-1'),
        transactionSeriesFixture(
          id: 'series-2',
          archivedAt: DateTime.utc(2026, 2, 1),
        ),
      ];

      when(
        () => repository.getAll(),
      ).thenAnswer((_) async => Success<List<TransactionSeries>>(series));

      // When
      final result = await useCase();

      // Then
      expect(result.valueOrNull, same(series));
      verify(() => repository.getAll()).called(1);
    });

    test('propagates repository failures', () async {
      // Given
      const failure = TestTransactionSeriesFailure(message: 'read failed');

      when(() => repository.getAll()).thenAnswer((_) async => failure);

      // When
      final result = await useCase();

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
