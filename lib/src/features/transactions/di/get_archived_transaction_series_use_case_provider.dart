import 'package:axiom/src/features/transactions/application/use_cases/get_archived_transaction_series_use_case.dart';
import 'package:axiom/src/features/transactions/di/transaction_series_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'get_archived_transaction_series_use_case_provider.g.dart';

/// Provides retrieval of archived transaction series.
@riverpod
GetArchivedTransactionSeriesUseCase getArchivedTransactionSeriesUseCase(
  Ref ref,
) {
  return GetArchivedTransactionSeriesUseCase(
    repository: ref.watch(transactionSeriesRepositoryProvider),
  );
}
