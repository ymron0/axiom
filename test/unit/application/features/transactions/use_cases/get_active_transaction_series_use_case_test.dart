@Tags(['application'])
library;

import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/application/use_cases/get_active_transaction_series_use_case.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction_series.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/transactions/transaction_series_failure_fixture.dart';
import '../../../../../fixtures/features/transactions/transaction_series_fixtures.dart';
import '../../../../../mocks/transaction_series_repository_mock.dart';

void main() {
  group('GetActiveTransactionSeriesUseCase', () {
    late MockTransactionSeriesRepository repository;
    late GetActiveTransactionSeriesUseCase useCase;

    setUp(() {
      repository = MockTransactionSeriesRepository();
      useCase = GetActiveTransactionSeriesUseCase(repository: repository);
    });

    test('returns active repository series', () async {
      // Given
      final series = <TransactionSeries>[
        transactionSeriesFixture(id: 'active-series'),
      ];

      when(
        () => repository.getActive(),
      ).thenAnswer((_) async => Success<List<TransactionSeries>>(series));

      // When
      final result = await useCase();

      // Then
      expect(result.valueOrNull, same(series));
      verify(() => repository.getActive()).called(1);
    });

    test('propagates repository failures', () async {
      // Given
      const failure = TestTransactionSeriesFailure(message: 'read failed');

      when(() => repository.getActive()).thenAnswer((_) async => failure);

      // When
      final result = await useCase();

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
