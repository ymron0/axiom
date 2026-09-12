import 'package:axiom/src/features/transactions/application/use_cases/delete_transaction_use_case.dart';
import 'package:axiom/src/features/transactions/di/transaction_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'delete_transaction_use_case_provider.g.dart';

/// Provides the use case for deleting one transaction.
@riverpod
DeleteTransactionUseCase deleteTransactionUseCase(Ref ref) {
  return DeleteTransactionUseCase(ref.watch(transactionRepositoryProvider));
}
