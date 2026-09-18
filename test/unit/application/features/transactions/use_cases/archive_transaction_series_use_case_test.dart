@Tags(['application'])
library;

import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/application/use_cases/archive_transaction_series_use_case.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction_series.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/transactions/transaction_series_failure_fixture.dart';
import '../../../../../fixtures/features/transactions/transaction_series_fixtures.dart';
import '../../../../../mocks/transaction_series_repository_mock.dart';

void main() {
  group('ArchiveTransactionSeriesUseCase', () {
    late MockTransactionSeriesRepository repository;
    late ArchiveTransactionSeriesUseCase useCase;

    final timestamp = DateTime.utc(2026, 2, 1);

    setUp(() {
      repository = MockTransactionSeriesRepository();
      useCase = ArchiveTransactionSeriesUseCase(
        repository: repository,
        clock: FixedClock(timestamp),
      );
    });

    test('archives the series with the injected clock time', () async {
      // Given
      final series = transactionSeriesFixture(
        id: 'archive-series',
        archivedAt: timestamp,
      );

      when(
        () => repository.archive(series.id, timestamp),
      ).thenAnswer((_) async => Success<TransactionSeries>(series));

      // When
      final result = await useCase(series.id);

      // Then
      expect(result.valueOrNull, same(series));
      verify(() => repository.archive(series.id, timestamp)).called(1);
    });

    test('propagates repository failures', () async {
      // Given
      final id = transactionSeriesFixture(id: 'archive-failure').id;
      const failure = TestTransactionSeriesFailure(message: 'archive failed');

      when(
        () => repository.archive(id, timestamp),
      ).thenAnswer((_) async => failure);

      // When
      final result = await useCase(id);

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
