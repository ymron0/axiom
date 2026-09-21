import 'package:axiom/src/core/di/clock_provider.dart';
import 'package:axiom/src/features/transactions/application/use_cases/unarchive_transaction_series_use_case.dart';
import 'package:axiom/src/features/transactions/di/transaction_series_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'unarchive_transaction_series_use_case_provider.g.dart';

/// Provides transaction-series unarchival.
@riverpod
UnarchiveTransactionSeriesUseCase unarchiveTransactionSeriesUseCase(Ref ref) {
  return UnarchiveTransactionSeriesUseCase(
    repository: ref.watch(transactionSeriesRepositoryProvider),
    clock: ref.watch(clockProvider),
  );
}
