import 'package:axiom/src/features/transactions/application/use_cases/get_transaction_offset_summary_use_case.dart';
import 'package:axiom/src/features/transactions/di/get_transaction_by_id_use_case_provider.dart';
import 'package:axiom/src/features/transactions/di/get_transaction_offsets_use_case_provider.dart';
import 'package:axiom/src/features/transactions/di/transaction_offset_policy_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'get_transaction_offset_summary_use_case_provider.g.dart';

/// Provides transaction-offset summary derivation.
@riverpod
GetTransactionOffsetSummaryUseCase getTransactionOffsetSummaryUseCase(Ref ref) {
  return GetTransactionOffsetSummaryUseCase(
    getTransactionById: ref.watch(getTransactionByIdUseCaseProvider),
    getTransactionOffsets: ref.watch(getTransactionOffsetsUseCaseProvider),
    offsetPolicy: ref.watch(transactionOffsetPolicyProvider),
  );
}
