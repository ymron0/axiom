import 'package:axiom/src/features/transactions/application/use_cases/create_transaction_offset_use_case.dart';
import 'package:axiom/src/features/transactions/di/transaction_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'create_transaction_offset_use_case_provider.g.dart';

/// Provides atomic transaction-offset creation.
@riverpod
CreateTransactionOffsetUseCase createTransactionOffsetUseCase(Ref ref) {
  return CreateTransactionOffsetUseCase(
    repository: ref.watch(transactionRepositoryProvider),
  );
}
