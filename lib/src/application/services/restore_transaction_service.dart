import 'package:axiom/src/application/services/validate_transaction_allocations_service.dart';
import 'package:axiom/src/application/services/validate_transaction_tags_service.dart';
import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/application/use_cases/restore_transaction_use_case.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';

/// Restores a transaction after validating all cross-feature references.
final class RestoreTransactionService {
  final RestoreTransactionUseCase _restoreTransaction;
  final ValidateTransactionAllocationsService _validateAllocations;
  final ValidateTransactionTagsService _validateTags;

  /// Creates a transaction restoration workflow.
  const RestoreTransactionService({
    required RestoreTransactionUseCase restoreTransaction,
    required ValidateTransactionAllocationsService validateAllocations,
    required ValidateTransactionTagsService validateTags,
  }) : _restoreTransaction = // ignore: prefer_initializing_formals
           restoreTransaction,
       _validateAllocations = // ignore: prefer_initializing_formals
           validateAllocations,
       _validateTags = validateTags; // ignore: prefer_initializing_formals

  /// Validates and restores [transaction].
  Future<Result<void, BaseFailure>> call(Transaction transaction) async {
    final allocationResult = await _validateAllocations(transaction);

    if (allocationResult case final Failure<BaseFailure> failure) {
      return failure;
    }

    final tagResult = await _validateTags.validateForRestore(
      transaction.tagIds,
    );

    if (tagResult case final Failure<BaseFailure> failure) {
      return failure;
    }

    return _restoreTransaction(transaction);
  }
}
