@Tags(['application', 'di'])
library;

import 'package:axiom/src/features/transactions/application/use_cases/restore_transaction_series_use_case.dart';
import 'package:axiom/src/features/transactions/di/restore_transaction_series_use_case_provider.dart';
import 'package:axiom/src/features/transactions/di/transaction_series_repository_provider.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

import '../../../../../mocks/transaction_series_repository_mock.dart';

void main() {
  group('restoreTransactionSeriesUseCase provider', () {
    test('resolves restore-transaction-series use case', () {
      // Given
      final repository = MockTransactionSeriesRepository();

      final container = ProviderContainer(
        overrides: [
          transactionSeriesRepositoryProvider.overrideWithValue(repository),
        ],
      );

      addTearDown(container.dispose);

      // When
      final useCase = container.read(restoreTransactionSeriesUseCaseProvider);

      // Then
      expect(useCase, isA<RestoreTransactionSeriesUseCase>());
    });
  });
}

