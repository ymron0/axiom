@Tags(['application'])
library;

import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/application/use_cases/get_archived_transaction_series_use_case.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction_series.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/transactions/transaction_series_failure_fixture.dart';
import '../../../../../fixtures/features/transactions/transaction_series_fixtures.dart';
import '../../../../../mocks/transaction_series_repository_mock.dart';

void main() {
  group('GetArchivedTransactionSeriesUseCase', () {
    late MockTransactionSeriesRepository repository;
    late GetArchivedTransactionSeriesUseCase useCase;

    setUp(() {
      repository = MockTransactionSeriesRepository();
      useCase = GetArchivedTransactionSeriesUseCase(repository: repository);
    });

    test('returns archived repository series', () async {
      // Given
      final series = <TransactionSeries>[
        transactionSeriesFixture(
          id: 'archived-series',
          archivedAt: DateTime.utc(2026, 2, 1),
        ),
      ];

      when(
        () => repository.getArchived(),
      ).thenAnswer((_) async => Success<List<TransactionSeries>>(series));

      // When
      final result = await useCase();

      // Then
      expect(result.valueOrNull, same(series));
      verify(() => repository.getArchived()).called(1);
    });

    test('propagates repository failures', () async {
      // Given
      const failure = TestTransactionSeriesFailure(message: 'read failed');

      when(() => repository.getArchived()).thenAnswer((_) async => failure);

      // When
      final result = await useCase();

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
