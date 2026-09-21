@Tags(['application', 'di'])
library;

import 'package:axiom/src/features/transactions/application/use_cases/get_transaction_series_by_id_use_case.dart';
import 'package:axiom/src/features/transactions/di/get_transaction_series_by_id_use_case_provider.dart';
import 'package:axiom/src/features/transactions/di/transaction_series_repository_provider.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

import '../../../../../mocks/transaction_series_repository_mock.dart';

void main() {
  group('getTransactionSeriesByIdUseCase provider', () {
    test('resolves get-transaction-series-by-id use case', () {
      // Given
      final repository = MockTransactionSeriesRepository();

      final container = ProviderContainer(
        overrides: [
          transactionSeriesRepositoryProvider.overrideWithValue(repository),
        ],
      );

      addTearDown(container.dispose);

      // When
      final useCase = container.read(getTransactionSeriesByIdUseCaseProvider);

      // Then
      expect(useCase, isA<GetTransactionSeriesByIdUseCase>());
    });
  });
}

