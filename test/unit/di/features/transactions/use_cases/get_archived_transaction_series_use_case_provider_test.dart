@Tags(['application', 'di'])
library;

import 'package:axiom/src/features/transactions/application/use_cases/get_archived_transaction_series_use_case.dart';
import 'package:axiom/src/features/transactions/di/get_archived_transaction_series_use_case_provider.dart';
import 'package:axiom/src/features/transactions/di/transaction_series_repository_provider.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

import '../../../../../mocks/transaction_series_repository_mock.dart';

void main() {
  group('getArchivedTransactionSeriesUseCase provider', () {
    test('resolves get-archived-transaction-series use case', () {
      // Given
      final repository = MockTransactionSeriesRepository();

      final container = ProviderContainer(
        overrides: [
          transactionSeriesRepositoryProvider.overrideWithValue(repository),
        ],
      );

      addTearDown(container.dispose);

      // When
      final useCase = container.read(getArchivedTransactionSeriesUseCaseProvider);

      // Then
      expect(useCase, isA<GetArchivedTransactionSeriesUseCase>());
    });
  });
}

