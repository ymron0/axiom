import 'package:axiom/src/application/di/services/validate_transaction_allocations_service_provider.dart';
import 'package:axiom/src/application/di/services/validate_transaction_tags_service_provider.dart';
import 'package:axiom/src/application/services/create_transaction_offset_service.dart';
import 'package:axiom/src/core/di/clock_provider.dart';
import 'package:axiom/src/features/transactions/di/create_transaction_offset_use_case_provider.dart';
import 'package:axiom/src/features/transactions/di/get_transaction_by_id_use_case_provider.dart';
import 'package:axiom/src/features/transactions/di/transaction_offset_policy_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'create_transaction_offset_service_provider.g.dart';

/// Provides the workflow for creating transaction offsets.
@riverpod
CreateTransactionOffsetService createTransactionOffsetService(Ref ref) {
  return CreateTransactionOffsetService(
    clock: ref.watch(clockProvider),
    getTransactionById: ref.watch(getTransactionByIdUseCaseProvider),
    createTransactionOffset: ref.watch(createTransactionOffsetUseCaseProvider),
    validateAllocations: ref.watch(
      validateTransactionAllocationsServiceProvider,
    ),
    validateTags: ref.watch(validateTransactionTagsServiceProvider),
    offsetPolicy: ref.watch(transactionOffsetPolicyProvider),
  );
}
