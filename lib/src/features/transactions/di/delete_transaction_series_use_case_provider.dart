import 'package:axiom/src/features/transactions/application/use_cases/delete_transaction_series_use_case.dart';
import 'package:axiom/src/features/transactions/di/transaction_series_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'delete_transaction_series_use_case_provider.g.dart';

/// Provides physical transaction-series deletion.
@riverpod
DeleteTransactionSeriesUseCase deleteTransactionSeriesUseCase(Ref ref) {
  return DeleteTransactionSeriesUseCase(
    repository: ref.watch(transactionSeriesRepositoryProvider),
  );
}

