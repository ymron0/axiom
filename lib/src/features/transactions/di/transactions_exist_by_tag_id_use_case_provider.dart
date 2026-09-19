import 'package:axiom/src/features/transactions/application/use_cases/transactions_exist_by_tag_id_use_case.dart';
import 'package:axiom/src/features/transactions/di/transaction_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'transactions_exist_by_tag_id_use_case_provider.g.dart';

/// Provides the transaction-reference query used by tag lifecycle workflows.
@riverpod
TransactionsExistByTagIdUseCase transactionsExistByTagIdUseCase(Ref ref) {
  return TransactionsExistByTagIdUseCase(
    ref.watch(transactionRepositoryProvider),
  );
}
