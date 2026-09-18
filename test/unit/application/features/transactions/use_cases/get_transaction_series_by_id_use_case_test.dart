@Tags(['application'])
library;

import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/application/use_cases/get_transaction_series_by_id_use_case.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction_series.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/transactions/transaction_series_failure_fixture.dart';
import '../../../../../fixtures/features/transactions/transaction_series_fixtures.dart';
import '../../../../../mocks/transaction_series_repository_mock.dart';

void main() {
  group('GetTransactionSeriesByIdUseCase', () {
    late MockTransactionSeriesRepository repository;
    late GetTransactionSeriesByIdUseCase useCase;

    setUp(() {
      repository = MockTransactionSeriesRepository();
      useCase = GetTransactionSeriesByIdUseCase(repository: repository);
    });

    test('returns the matching transaction series', () async {
      // Given
      final series = transactionSeriesFixture(id: 'series-by-id');

      when(
        () => repository.getById(series.id),
      ).thenAnswer((_) async => Success<TransactionSeries?>(series));

      // When
      final result = await useCase(series.id);

      // Then
      expect(result.valueOrNull, same(series));
      verify(() => repository.getById(series.id)).called(1);
    });

    test('returns successful null when the series does not exist', () async {
      // Given
      final id = transactionSeriesFixture(id: 'missing-series').id;

      when(
        () => repository.getById(id),
      ).thenAnswer((_) async => const Success<TransactionSeries?>(null));

      // When
      final result = await useCase(id);

      // Then
      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, isNull);
    });

    test('propagates repository failures', () async {
      // Given
      final id = transactionSeriesFixture(id: 'lookup-failure').id;
      const failure = TestTransactionSeriesFailure(message: 'lookup failed');

      when(() => repository.getById(id)).thenAnswer((_) async => failure);

      // When
      final result = await useCase(id);

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
