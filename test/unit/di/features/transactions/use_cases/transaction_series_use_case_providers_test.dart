@Tags(['application', 'di'])
library;

import 'package:axiom/src/core/di/clock_provider.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/features/transactions/application/use_cases/archive_transaction_series_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/create_transaction_series_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/delete_transaction_series_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/get_active_transaction_series_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/get_archived_transaction_series_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/get_transaction_series_by_id_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/get_transaction_series_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/restore_transaction_series_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/transaction_series_exist_by_account_id_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/transaction_series_exist_by_category_id_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/transaction_series_exist_by_jar_id_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/transaction_series_exist_by_merchant_id_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/unarchive_transaction_series_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/update_transaction_series_use_case.dart';
import 'package:axiom/src/features/transactions/di/transaction_series_repository_provider.dart';
import 'package:axiom/src/features/transactions/di/transaction_series_use_case_providers.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';

import '../../../../../mocks/transaction_series_repository_mock.dart';

void main() {
  group('transaction-series use-case providers', () {
    test('resolve every transaction-series use case', () {
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

      // When / Then
      expect(
        container.read(createTransactionSeriesUseCaseProvider),
        isA<CreateTransactionSeriesUseCase>(),
      );

      expect(
        container.read(getTransactionSeriesUseCaseProvider),
        isA<GetTransactionSeriesUseCase>(),
      );

      expect(
        container.read(getActiveTransactionSeriesUseCaseProvider),
        isA<GetActiveTransactionSeriesUseCase>(),
      );

      expect(
        container.read(getArchivedTransactionSeriesUseCaseProvider),
        isA<GetArchivedTransactionSeriesUseCase>(),
      );

      expect(
        container.read(getTransactionSeriesByIdUseCaseProvider),
        isA<GetTransactionSeriesByIdUseCase>(),
      );

      expect(
        container.read(updateTransactionSeriesUseCaseProvider),
        isA<UpdateTransactionSeriesUseCase>(),
      );

      expect(
        container.read(archiveTransactionSeriesUseCaseProvider),
        isA<ArchiveTransactionSeriesUseCase>(),
      );

      expect(
        container.read(unarchiveTransactionSeriesUseCaseProvider),
        isA<UnarchiveTransactionSeriesUseCase>(),
      );

      expect(
        container.read(deleteTransactionSeriesUseCaseProvider),
        isA<DeleteTransactionSeriesUseCase>(),
      );

      expect(
        container.read(restoreTransactionSeriesUseCaseProvider),
        isA<RestoreTransactionSeriesUseCase>(),
      );

      expect(
        container.read(transactionSeriesExistByAccountIdUseCaseProvider),
        isA<TransactionSeriesExistByAccountIdUseCase>(),
      );

      expect(
        container.read(transactionSeriesExistByMerchantIdUseCaseProvider),
        isA<TransactionSeriesExistByMerchantIdUseCase>(),
      );

      expect(
        container.read(transactionSeriesExistByCategoryIdUseCaseProvider),
        isA<TransactionSeriesExistByCategoryIdUseCase>(),
      );

      expect(
        container.read(transactionSeriesExistByJarIdUseCaseProvider),
        isA<TransactionSeriesExistByJarIdUseCase>(),
      );
    });
  });
}
