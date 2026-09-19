import 'package:axiom/src/application/services/assign_tag_to_transaction_service.dart';
import 'package:axiom/src/core/di/clock_provider.dart';
import 'package:axiom/src/features/tags/di/get_tag_by_id_use_case_provider.dart';
import 'package:axiom/src/features/transactions/di/get_transaction_by_id_use_case_provider.dart';
import 'package:axiom/src/features/transactions/di/update_transaction_use_case_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'assign_tag_to_transaction_service_provider.g.dart';

/// Provides tag assignment to existing transactions.
@riverpod
AssignTagToTransactionService assignTagToTransactionService(Ref ref) {
  return AssignTagToTransactionService(
    clock: ref.watch(clockProvider),
    getTransactionById: ref.watch(getTransactionByIdUseCaseProvider),
    getTagById: ref.watch(getTagByIdUseCaseProvider),
    updateTransaction: ref.watch(updateTransactionUseCaseProvider),
  );
}
