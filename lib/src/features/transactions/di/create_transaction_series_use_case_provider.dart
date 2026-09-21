import 'package:axiom/src/features/transactions/application/use_cases/create_transaction_series_use_case.dart';
import 'package:axiom/src/features/transactions/di/transaction_series_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'create_transaction_series_use_case_provider.g.dart';

/// Provides transaction-series creation.
@riverpod
CreateTransactionSeriesUseCase createTransactionSeriesUseCase(Ref ref) {
  return CreateTransactionSeriesUseCase(
    repository: ref.watch(transactionSeriesRepositoryProvider),
  );
}
