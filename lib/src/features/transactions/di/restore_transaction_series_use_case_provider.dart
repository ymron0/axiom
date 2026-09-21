import 'package:axiom/src/features/transactions/application/use_cases/restore_transaction_series_use_case.dart';
import 'package:axiom/src/features/transactions/di/transaction_series_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'restore_transaction_series_use_case_provider.g.dart';

/// Provides transaction-series restoration.
@riverpod
RestoreTransactionSeriesUseCase restoreTransactionSeriesUseCase(Ref ref) {
  return RestoreTransactionSeriesUseCase(
    repository: ref.watch(transactionSeriesRepositoryProvider),
  );
}

