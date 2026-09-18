@Tags(['application'])
library;

import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/application/use_cases/unarchive_transaction_series_use_case.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction_series.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/transactions/transaction_series_failure_fixture.dart';
import '../../../../../fixtures/features/transactions/transaction_series_fixtures.dart';
import '../../../../../mocks/transaction_series_repository_mock.dart';

void main() {
  group('UnarchiveTransactionSeriesUseCase', () {
    late MockTransactionSeriesRepository repository;
    late UnarchiveTransactionSeriesUseCase useCase;

    final timestamp = DateTime.utc(2026, 3, 1);

    setUp(() {
      repository = MockTransactionSeriesRepository();
      useCase = UnarchiveTransactionSeriesUseCase(
        repository: repository,
        clock: FixedClock(timestamp),
      );
    });

    test('unarchives the series with the injected clock time', () async {
      // Given
      final series = transactionSeriesFixture(
        id: 'unarchived-series',
        modifiedAt: timestamp,
      );

      when(
        () => repository.unarchive(series.id, timestamp),
      ).thenAnswer((_) async => Success<TransactionSeries>(series));

      // When
      final result = await useCase(series.id);

      // Then
      expect(result.valueOrNull, same(series));
      verify(() => repository.unarchive(series.id, timestamp)).called(1);
    });

    test('propagates repository failures', () async {
      // Given
      final id = transactionSeriesFixture(id: 'unarchive-failure').id;
      const failure = TestTransactionSeriesFailure(message: 'unarchive failed');

      when(
        () => repository.unarchive(id, timestamp),
      ).thenAnswer((_) async => failure);

      // When
      final result = await useCase(id);

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
