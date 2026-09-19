import 'package:axiom/src/application/services/generate_planned_transactions_service.dart';
import 'package:axiom/src/features/transactions/domain/services/resize_planned_transaction_template_service.dart';
import 'package:axiom/src/core/di/clock_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'generate_planned_transactions_service_provider.g.dart';

/// Provides planned-transaction occurrence generation.
@riverpod
GeneratePlannedTransactionsService generatePlannedTransactionsService(Ref ref) {
  return GeneratePlannedTransactionsService(
    clock: ref.watch(clockProvider),
    resizeTemplate: const ResizePlannedTransactionTemplateService(),
  );
}
