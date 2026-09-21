import 'package:axiom/src/application/di/services/generate_planned_transactions_service_provider.dart';
import 'package:axiom/src/application/services/delete_transaction_occurrence_service.dart';
import 'package:axiom/src/core/di/clock_provider.dart';
import 'package:axiom/src/features/transactions/di/create_transaction_use_case_provider.dart';
import 'package:axiom/src/features/transactions/di/delete_transaction_use_case_provider.dart';
import 'package:axiom/src/features/transactions/di/get_transaction_by_id_use_case_provider.dart';
import 'package:axiom/src/features/transactions/di/restore_transaction_use_case_provider.dart';
import 'package:axiom/src/features/transactions/di/transaction_series_use_case_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'delete_transaction_occurrence_service_provider.g.dart';

/// Provides occurrence-aware transaction deletion.
@riverpod
DeleteTransactionOccurrenceService deleteTransactionOccurrenceService(Ref ref) {
  return DeleteTransactionOccurrenceService(
    getTransactionById: ref.watch(getTransactionByIdUseCaseProvider),
    getSeriesById: ref.watch(getTransactionSeriesByIdUseCaseProvider),
    updateSeries: ref.watch(updateTransactionSeriesUseCaseProvider),
    deleteTransaction: ref.watch(deleteTransactionUseCaseProvider),
    restoreTransaction: ref.watch(restoreTransactionUseCaseProvider),
    createTransaction: ref.watch(createTransactionUseCaseProvider),
    generate: ref.watch(generatePlannedTransactionsServiceProvider),
    clock: ref.watch(clockProvider),
  );
}
