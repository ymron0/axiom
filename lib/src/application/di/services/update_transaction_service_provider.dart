import 'package:axiom/src/application/di/services/validate_transaction_allocations_service_provider.dart';
import 'package:axiom/src/application/services/update_transaction_service.dart';
import 'package:axiom/src/features/transactions/di/update_transaction_use_case_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'update_transaction_service_provider.g.dart';

/// Provides the workflow for updating validated transactions.
@riverpod
UpdateTransactionService updateTransactionService(Ref ref) {
  return UpdateTransactionService(
    updateTransaction: ref.watch(updateTransactionUseCaseProvider),
    validateAllocations: ref.watch(
      validateTransactionAllocationsServiceProvider,
    ),
  );
}
