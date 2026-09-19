import 'package:axiom/src/application/di/services/validate_transaction_allocations_service_provider.dart';
import 'package:axiom/src/application/di/services/validate_transaction_tags_service_provider.dart';
import 'package:axiom/src/application/services/restore_transaction_service.dart';
import 'package:axiom/src/features/transactions/di/restore_transaction_use_case_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'restore_transaction_service_provider.g.dart';

/// Provides the workflow for restoring validated transactions.
@riverpod
RestoreTransactionService restoreTransactionService(Ref ref) {
  return RestoreTransactionService(
    restoreTransaction: ref.watch(restoreTransactionUseCaseProvider),
    validateAllocations: ref.watch(
      validateTransactionAllocationsServiceProvider,
    ),
    validateTags: ref.watch(validateTransactionTagsServiceProvider),
  );
}
