import 'package:axiom/src/application/services/validate_transaction_allocations_service.dart';
import 'package:axiom/src/application/services/validate_transaction_asset_semantics_service.dart';
import 'package:axiom/src/application/services/validate_transaction_budgets_service.dart';
import 'package:axiom/src/application/services/validate_transaction_tags_service.dart';
import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/application/use_cases/get_transaction_by_id_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/update_transaction_use_case.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_failure.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_not_found_failure.dart';

/// Updates a transaction after validating cross-feature relationships.
final class UpdateTransactionService {
  final GetTransactionByIdUseCase _getTransactionById;

  final UpdateTransactionUseCase _updateTransaction;
  final ValidateTransactionAssetSemanticsService _validateAssets;
  final ValidateTransactionAllocationsService _validateAllocations;
  final ValidateTransactionTagsService _validateTags;
  final ValidateTransactionBudgetsService _validateBudgets;

  /// Creates the transaction update workflow.
  const UpdateTransactionService({
    required GetTransactionByIdUseCase getTransactionById,
    required UpdateTransactionUseCase updateTransaction,
    required ValidateTransactionAssetSemanticsService validateAssets,
    required ValidateTransactionAllocationsService validateAllocations,
    required ValidateTransactionTagsService validateTags,
    required ValidateTransactionBudgetsService validateBudgets,
  }) : _getTransactionById = // ignore: prefer_initializing_formals
           getTransactionById,
       _updateTransaction = // ignore: prefer_initializing_formals
           updateTransaction,
       _validateAssets = validateAssets, // ignore: prefer_initializing_formals
       _validateAllocations = // ignore: prefer_initializing_formals
           validateAllocations,
       _validateTags = validateTags, // ignore: prefer_initializing_formals
       _validateBudgets = // ignore: prefer_initializing_formals
           validateBudgets;

  /// Validates and persists [transaction].
  Future<Result<void, BaseFailure>> call(Transaction transaction) async {
    final existingResult = await _getTransactionById(transaction.id);

    if (existingResult case final Failure<TransactionFailure> failure) {
      return failure;
    }

    final existing = existingResult.valueOrNull;

    if (existing == null) {
      return TransactionNotFoundFailure(
        message:
            'Transaction ID was not found: '
            '${transaction.id.value}',
      );
    }

    final assetResult = await _validateAssets(transaction);

    if (assetResult case final Failure<BaseFailure> failure) {
      return failure;
    }

    final allocationResult = await _validateAllocations(transaction);

    if (allocationResult case final Failure<BaseFailure> failure) {
      return failure;
    }

    final tagResult = await _validateTags.validateForUpdate(
      previousTagIds: existing.tagIds,
      nextTagIds: transaction.tagIds,
    );

    if (tagResult case final Failure<BaseFailure> failure) {
      return failure;
    }

    final budgetResult = await _validateBudgets(
      transaction,
      previous: existing,
    );

    if (budgetResult case final Failure<BaseFailure> failure) {
      return failure;
    }

    return _updateTransaction(transaction);
  }
}
