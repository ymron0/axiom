import 'package:axiom/src/features/transactions/application/use_cases/get_transaction_offsets_use_case.dart';
import 'package:axiom/src/features/transactions/di/transaction_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'get_transaction_offsets_use_case_provider.g.dart';

/// Provides transaction-offset retrieval.
@riverpod
GetTransactionOffsetsUseCase getTransactionOffsetsUseCase(Ref ref) {
  return GetTransactionOffsetsUseCase(
    repository: ref.watch(transactionRepositoryProvider),
  );
}
