@Tags(['application'])
library;

import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/application/use_cases/restore_transaction_series_use_case.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/transactions/transaction_series_failure_fixture.dart';
import '../../../../../fixtures/features/transactions/transaction_series_fixtures.dart';
import '../../../../../mocks/transaction_series_repository_mock.dart';

void main() {
  group('RestoreTransactionSeriesUseCase', () {
    late MockTransactionSeriesRepository repository;
    late RestoreTransactionSeriesUseCase useCase;

    setUp(() {
      repository = MockTransactionSeriesRepository();
      useCase = RestoreTransactionSeriesUseCase(repository: repository);
    });

    test('restores the caller-retained deleted snapshot', () async {
      // Given
      final series = transactionSeriesFixture(
        id: 'restore-series',
        deletedAt: DateTime.utc(2026, 2, 1),
      );

      when(
        () => repository.restore(series),
      ).thenAnswer((_) async => const Success(null));

      // When
      final result = await useCase(series);

      // Then
      expect(result.isSuccess, isTrue);
      verify(() => repository.restore(series)).called(1);
    });

    test('propagates repository failures', () async {
      // Given
      final series = transactionSeriesFixture(
        id: 'restore-failure',
        deletedAt: DateTime.utc(2026, 2, 1),
      );

      const failure = TestTransactionSeriesFailure(message: 'restore failed');

      when(() => repository.restore(series)).thenAnswer((_) async => failure);

      // When
      final result = await useCase(series);

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
