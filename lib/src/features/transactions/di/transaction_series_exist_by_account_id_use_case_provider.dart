import 'package:axiom/src/features/transactions/application/use_cases/transaction_series_exist_by_account_id_use_case.dart';
import 'package:axiom/src/features/transactions/di/transaction_series_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'transaction_series_exist_by_account_id_use_case_provider.g.dart';

/// Provides account-reference checks against transaction series.
@riverpod
TransactionSeriesExistByAccountIdUseCase
transactionSeriesExistByAccountIdUseCase(Ref ref) {
  return TransactionSeriesExistByAccountIdUseCase(
    repository: ref.watch(transactionSeriesRepositoryProvider),
  );
}
