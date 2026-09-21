@Tags(['application', 'di'])
library;

import 'package:axiom/src/features/transactions/application/use_cases/transaction_series_exist_by_jar_id_use_case.dart';
import 'package:axiom/src/features/transactions/di/transaction_series_exist_by_jar_id_use_case_provider.dart';
import 'package:axiom/src/features/transactions/di/transaction_series_repository_provider.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

import '../../../../../mocks/transaction_series_repository_mock.dart';

void main() {
  group('transactionSeriesExistByJarIdUseCase provider', () {
    test('resolves transaction-series-exist-by-jar-id use case', () {
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
        transactionSeriesExistByJarIdUseCaseProvider,
      );

      // Then
      expect(useCase, isA<TransactionSeriesExistByJarIdUseCase>());
    });
  });
}
