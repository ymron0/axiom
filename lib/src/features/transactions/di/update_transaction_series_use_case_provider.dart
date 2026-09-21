import 'package:axiom/src/features/transactions/application/use_cases/update_transaction_series_use_case.dart';
import 'package:axiom/src/features/transactions/di/transaction_series_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'update_transaction_series_use_case_provider.g.dart';

/// Provides transaction-series updates.
@riverpod
UpdateTransactionSeriesUseCase updateTransactionSeriesUseCase(Ref ref) {
  return UpdateTransactionSeriesUseCase(
    repository: ref.watch(transactionSeriesRepositoryProvider),
  );
}
