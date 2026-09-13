import 'package:axiom/src/application/di/services/validate_transaction_allocations_service_provider.dart';
import 'package:axiom/src/application/services/create_transaction_service.dart';
import 'package:axiom/src/core/di/clock_provider.dart';
import 'package:axiom/src/features/transactions/di/create_transaction_use_case_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'create_transaction_service_provider.g.dart';

/// Provides the workflow for creating validated transactions.
@riverpod
CreateTransactionService createTransactionService(Ref ref) {
  return CreateTransactionService(
    clock: ref.watch(clockProvider),
    createTransaction: ref.watch(createTransactionUseCaseProvider),
    validateAllocations: ref.watch(
      validateTransactionAllocationsServiceProvider,
    ),
  );
}
