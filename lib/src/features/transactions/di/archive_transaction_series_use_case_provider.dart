import 'package:axiom/src/core/di/clock_provider.dart';
import 'package:axiom/src/features/transactions/application/use_cases/archive_transaction_series_use_case.dart';
import 'package:axiom/src/features/transactions/di/transaction_series_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'archive_transaction_series_use_case_provider.g.dart';

/// Provides transaction-series archival.
@riverpod
ArchiveTransactionSeriesUseCase archiveTransactionSeriesUseCase(Ref ref) {
  return ArchiveTransactionSeriesUseCase(
    repository: ref.watch(transactionSeriesRepositoryProvider),
    clock: ref.watch(clockProvider),
  );
}
