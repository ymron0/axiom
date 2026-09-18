@Tags(['application'])
library;

import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/application/use_cases/create_transaction_series_use_case.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/transactions/transaction_series_failure_fixture.dart';
import '../../../../../fixtures/features/transactions/transaction_series_fixtures.dart';
import '../../../../../mocks/transaction_series_repository_mock.dart';

void main() {
  group('CreateTransactionSeriesUseCase', () {
    late MockTransactionSeriesRepository repository;
    late CreateTransactionSeriesUseCase useCase;

    setUp(() {
      repository = MockTransactionSeriesRepository();
      useCase = CreateTransactionSeriesUseCase(repository: repository);
    });

    test('delegates creation to the repository', () async {
      // Given
      final series = transactionSeriesFixture(id: 'create-series');
      when(
        () => repository.create(series),
      ).thenAnswer((_) async => const Success(null));

      // When
      final result = await useCase(series);

      // Then
      expect(result.isSuccess, isTrue);
      verify(() => repository.create(series)).called(1);
    });

    test('propagates repository failures', () async {
      // Given
      final series = transactionSeriesFixture(id: 'duplicate-series');
      const failure = TestTransactionSeriesFailure(message: 'duplicate');

      when(() => repository.create(series)).thenAnswer((_) async => failure);

      // When
      final result = await useCase(series);

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
