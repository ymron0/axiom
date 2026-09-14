import 'package:axiom/src/features/transactions/application/use_cases/transactions_exist_by_jar_id_use_case.dart';
import 'package:axiom/src/features/transactions/di/transaction_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'transactions_exist_by_jar_id_use_case_provider.g.dart';

/// Provides the use case that checks whether a jar has transactions.
@riverpod
TransactionsExistByJarIdUseCase transactionsExistByJarIdUseCase(Ref ref) {
  return TransactionsExistByJarIdUseCase(
    ref.watch(transactionRepositoryProvider),
  );
}
