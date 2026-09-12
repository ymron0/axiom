import 'package:axiom/src/features/transactions/application/use_cases/get_all_transactions_use_case.dart';
import 'package:axiom/src/features/transactions/di/transaction_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'get_all_transactions_use_case_provider.g.dart';

/// Provides the use case for retrieving all transactions.
@riverpod
GetAllTransactionsUseCase getAllTransactionsUseCase(Ref ref) {
  return GetAllTransactionsUseCase(ref.watch(transactionRepositoryProvider));
}
