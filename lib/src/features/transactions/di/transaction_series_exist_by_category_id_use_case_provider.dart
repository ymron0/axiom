import 'package:axiom/src/features/transactions/application/use_cases/transaction_series_exist_by_category_id_use_case.dart';
import 'package:axiom/src/features/transactions/di/transaction_series_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'transaction_series_exist_by_category_id_use_case_provider.g.dart';

/// Provides category-reference checks against transaction series.
@riverpod
TransactionSeriesExistByCategoryIdUseCase
transactionSeriesExistByCategoryIdUseCase(Ref ref) {
  return TransactionSeriesExistByCategoryIdUseCase(
    repository: ref.watch(transactionSeriesRepositoryProvider),
  );
}
