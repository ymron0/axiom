import 'package:axiom/src/features/transactions/application/use_cases/query_transactions_use_case.dart';
import 'package:axiom/src/features/transactions/di/transaction_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'query_transactions_use_case_provider.g.dart';

/// Provides the use case for querying transactions.
@riverpod
QueryTransactionsUseCase queryTransactionsUseCase(Ref ref) {
  return QueryTransactionsUseCase(ref.watch(transactionRepositoryProvider));
}
