import 'package:axiom/src/application/di/services/update_transaction_service_provider.dart';
import 'package:axiom/src/application/services/convert_planned_transaction_to_actual_service.dart';
import 'package:axiom/src/core/di/clock_provider.dart';
import 'package:axiom/src/features/transactions/di/get_transaction_by_id_use_case_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'convert_planned_transaction_to_actual_service_provider.g.dart';

/// Provides the workflow for converting a planned transaction to actual.
@riverpod
ConvertPlannedTransactionToActualService
convertPlannedTransactionToActualService(Ref ref) {
  return ConvertPlannedTransactionToActualService(
    clock: ref.watch(clockProvider),
    getTransactionById: ref.watch(getTransactionByIdUseCaseProvider),
    updateTransaction: ref.watch(updateTransactionServiceProvider),
  );
}
