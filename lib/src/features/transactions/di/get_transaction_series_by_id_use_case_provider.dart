import 'package:axiom/src/features/transactions/application/use_cases/get_transaction_series_by_id_use_case.dart';
import 'package:axiom/src/features/transactions/di/transaction_series_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'get_transaction_series_by_id_use_case_provider.g.dart';

/// Provides transaction-series lookup by identity.
@riverpod
GetTransactionSeriesByIdUseCase getTransactionSeriesByIdUseCase(Ref ref) {
  return GetTransactionSeriesByIdUseCase(
    repository: ref.watch(transactionSeriesRepositoryProvider),
  );
}
