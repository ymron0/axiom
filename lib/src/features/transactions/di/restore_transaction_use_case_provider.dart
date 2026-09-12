import 'package:axiom/src/features/transactions/application/use_cases/restore_transaction_use_case.dart';
import 'package:axiom/src/features/transactions/di/transaction_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'restore_transaction_use_case_provider.g.dart';

/// Provides the use case for restoring one transaction.
@riverpod
RestoreTransactionUseCase restoreTransactionUseCase(Ref ref) {
  return RestoreTransactionUseCase(ref.watch(transactionRepositoryProvider));
}
