@Tags(['application'])
library;

import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/application/use_cases/update_transaction_series_use_case.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/transactions/transaction_series_failure_fixture.dart';
import '../../../../../fixtures/features/transactions/transaction_series_fixtures.dart';
import '../../../../../mocks/transaction_series_repository_mock.dart';

void main() {
  group('UpdateTransactionSeriesUseCase', () {
    late MockTransactionSeriesRepository repository;
    late UpdateTransactionSeriesUseCase useCase;

    setUp(() {
      repository = MockTransactionSeriesRepository();
      useCase = UpdateTransactionSeriesUseCase(repository: repository);
    });

    test('delegates the replacement snapshot to the repository', () async {
      // Given
      final series = transactionSeriesFixture(id: 'update-series');

      when(
        () => repository.update(series),
      ).thenAnswer((_) async => const Success(null));

      // When
      final result = await useCase(series);

      // Then
      expect(result.isSuccess, isTrue);
      verify(() => repository.update(series)).called(1);
    });

    test('propagates repository failures', () async {
      // Given
      final series = transactionSeriesFixture(id: 'update-failure');
      const failure = TestTransactionSeriesFailure(message: 'update failed');

      when(() => repository.update(series)).thenAnswer((_) async => failure);

      // When
      final result = await useCase(series);

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
