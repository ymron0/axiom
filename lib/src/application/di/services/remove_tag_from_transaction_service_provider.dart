import 'package:axiom/src/application/services/remove_tag_from_transaction_service.dart';
import 'package:axiom/src/core/di/clock_provider.dart';
import 'package:axiom/src/features/transactions/di/get_transaction_by_id_use_case_provider.dart';
import 'package:axiom/src/features/transactions/di/update_transaction_use_case_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'remove_tag_from_transaction_service_provider.g.dart';

/// Provides tag removal from existing transactions.
@riverpod
RemoveTagFromTransactionService removeTagFromTransactionService(Ref ref) {
  return RemoveTagFromTransactionService(
    clock: ref.watch(clockProvider),
    getTransactionById: ref.watch(getTransactionByIdUseCaseProvider),
    updateTransaction: ref.watch(updateTransactionUseCaseProvider),
  );
}
