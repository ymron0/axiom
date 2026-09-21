@Tags(['application', 'di'])
library;

import 'package:axiom/src/features/transactions/application/use_cases/transaction_series_exist_by_category_id_use_case.dart';
import 'package:axiom/src/features/transactions/di/transaction_series_exist_by_category_id_use_case_provider.dart';
import 'package:axiom/src/features/transactions/di/transaction_series_repository_provider.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

import '../../../../../mocks/transaction_series_repository_mock.dart';

void main() {
  group('transactionSeriesExistByCategoryIdUseCase provider', () {
    test('resolves transaction-series-exist-by-category-id use case', () {
      // Given
      final repository = MockTransactionSeriesRepository();

      final container = ProviderContainer(
        overrides: [
          transactionSeriesRepositoryProvider.overrideWithValue(repository),
        ],
      );

      addTearDown(container.dispose);

      // When
      final useCase = container.read(
        transactionSeriesExistByCategoryIdUseCaseProvider,
      );

      // Then
      expect(useCase, isA<TransactionSeriesExistByCategoryIdUseCase>());
    });
  });
}

