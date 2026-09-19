import 'package:axiom/src/features/transactions/application/use_cases/get_transactions_by_tag_id_use_case.dart';
import 'package:axiom/src/features/transactions/di/transaction_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'get_transactions_by_tag_id_use_case_provider.g.dart';

/// Provides the use case for retrieving transactions by tag.
@riverpod
GetTransactionsByTagIdUseCase getTransactionsByTagIdUseCase(Ref ref) {
  return GetTransactionsByTagIdUseCase(
    ref.watch(transactionRepositoryProvider),
  );
}