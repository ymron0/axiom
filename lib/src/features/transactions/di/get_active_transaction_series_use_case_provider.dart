import 'package:axiom/src/features/transactions/application/use_cases/get_active_transaction_series_use_case.dart';
import 'package:axiom/src/features/transactions/di/transaction_series_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'get_active_transaction_series_use_case_provider.g.dart';

/// Provides retrieval of active transaction series.
@riverpod
GetActiveTransactionSeriesUseCase getActiveTransactionSeriesUseCase(Ref ref) {
  return GetActiveTransactionSeriesUseCase(
    repository: ref.watch(transactionSeriesRepositoryProvider),
  );
}

