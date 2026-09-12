import 'package:axiom/src/features/transactions/application/use_cases/create_all_transactions_use_case.dart';
import 'package:axiom/src/features/transactions/di/transaction_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'create_all_transactions_use_case_provider.g.dart';

/// Provides the use case for creating multiple transactions.
@riverpod
CreateAllTransactionsUseCase createAllTransactionsUseCase(Ref ref) {
  return CreateAllTransactionsUseCase(
    ref.watch(transactionRepositoryProvider),
  );
}
