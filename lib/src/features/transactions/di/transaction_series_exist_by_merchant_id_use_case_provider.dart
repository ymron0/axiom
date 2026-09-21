import 'package:axiom/src/features/transactions/application/use_cases/transaction_series_exist_by_merchant_id_use_case.dart';
import 'package:axiom/src/features/transactions/di/transaction_series_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'transaction_series_exist_by_merchant_id_use_case_provider.g.dart';

/// Provides merchant-reference checks against transaction series.
@riverpod
TransactionSeriesExistByMerchantIdUseCase
transactionSeriesExistByMerchantIdUseCase(Ref ref) {
  return TransactionSeriesExistByMerchantIdUseCase(
    repository: ref.watch(transactionSeriesRepositoryProvider),
  );
}

