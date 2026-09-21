@Tags(['application', 'di'])
library;

import 'package:axiom/src/core/di/clock_provider.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/features/transactions/application/use_cases/archive_transaction_series_use_case.dart';
import 'package:axiom/src/features/transactions/di/archive_transaction_series_use_case_provider.dart';
import 'package:axiom/src/features/transactions/di/transaction_series_repository_provider.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

import '../../../../../mocks/transaction_series_repository_mock.dart';

void main() {
  group('archiveTransactionSeriesUseCase provider', () {
    test('resolves archive-transaction-series use case', () {
      // Given
      final repository = MockTransactionSeriesRepository();

      final container = ProviderContainer(
        overrides: [
          transactionSeriesRepositoryProvider.overrideWithValue(repository),
          clockProvider.overrideWithValue(
            FixedClock(DateTime.utc(2026, 9, 19)),
          ),
        ],
      );

      addTearDown(container.dispose);

      // When
      final useCase = container.read(archiveTransactionSeriesUseCaseProvider);

      // Then
      expect(useCase, isA<ArchiveTransactionSeriesUseCase>());
    });
  });
}
