@Tags(['application', 'di'])
library;

import 'package:axiom/src/application/di/services/delete_transaction_occurrence_service_provider.dart';
import 'package:axiom/src/application/di/services/generate_planned_transactions_service_provider.dart';
import 'package:axiom/src/application/services/delete_transaction_occurrence_service.dart';
import 'package:axiom/src/application/services/generate_planned_transactions_service.dart';
import 'package:axiom/src/core/di/clock_provider.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/features/transactions/application/use_cases/create_transaction_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/delete_transaction_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/get_transaction_by_id_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/get_transaction_series_by_id_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/restore_transaction_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/update_transaction_series_use_case.dart';
import 'package:axiom/src/features/transactions/di/create_transaction_use_case_provider.dart';
import 'package:axiom/src/features/transactions/di/delete_transaction_use_case_provider.dart';
import 'package:axiom/src/features/transactions/di/get_transaction_by_id_use_case_provider.dart';
import 'package:axiom/src/features/transactions/di/restore_transaction_use_case_provider.dart';
import 'package:axiom/src/features/transactions/di/transaction_series_use_case_providers.dart';
import 'package:axiom/src/features/transactions/domain/services/resize_planned_transaction_template_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:test/test.dart';

import '../../../../mocks/transaction_repository_mock.dart';
import '../../../../mocks/transaction_series_repository_mock.dart';

void main() {
  group('deleteTransactionOccurrenceServiceProvider', () {
    test('provides the delete transaction occurrence service', () {
      // Given
      final transactionRepository = MockTransactionRepository();
      final seriesRepository = MockTransactionSeriesRepository();
      final clock = FixedClock(DateTime.utc(2026, 9, 21));

      final container = ProviderContainer(
        overrides: [
          clockProvider.overrideWithValue(clock),
          getTransactionByIdUseCaseProvider.overrideWithValue(
            GetTransactionByIdUseCase(transactionRepository),
          ),
          getTransactionSeriesByIdUseCaseProvider.overrideWithValue(
            GetTransactionSeriesByIdUseCase(repository: seriesRepository),
          ),
          updateTransactionSeriesUseCaseProvider.overrideWithValue(
            UpdateTransactionSeriesUseCase(repository: seriesRepository),
          ),
          deleteTransactionUseCaseProvider.overrideWithValue(
            DeleteTransactionUseCase(transactionRepository),
          ),
          restoreTransactionUseCaseProvider.overrideWithValue(
            RestoreTransactionUseCase(transactionRepository),
          ),
          createTransactionUseCaseProvider.overrideWithValue(
            CreateTransactionUseCase(repository: transactionRepository),
          ),
          generatePlannedTransactionsServiceProvider.overrideWithValue(
            GeneratePlannedTransactionsService(
              clock: clock,
              resizeTemplate: const ResizePlannedTransactionTemplateService(),
            ),
          ),
        ],
      );

      addTearDown(container.dispose);

      // When
      final service = container.read(
        deleteTransactionOccurrenceServiceProvider,
      );

      // Then
      expect(service, isA<DeleteTransactionOccurrenceService>());
    });
  });
}

