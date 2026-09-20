import 'package:axiom/src/application/services/validate_transaction_allocations_service.dart';
import 'package:axiom/src/application/services/validate_transaction_asset_semantics_service.dart';
import 'package:axiom/src/application/services/validate_transaction_budgets_service.dart';
import 'package:axiom/src/application/services/validate_transaction_tags_service.dart';
import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/ports/clock/clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/application/commands/create_transaction_command.dart';
import 'package:axiom/src/features/transactions/application/use_cases/create_transaction_use_case.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';

/// Creates a transaction after validating all cross-feature relationships.
final class CreateTransactionService {
  final Clock _clock;

  final CreateTransactionUseCase _createTransaction;
  final ValidateTransactionAssetSemanticsService _validateAssets;
  final ValidateTransactionAllocationsService _validateAllocations;
  final ValidateTransactionTagsService _validateTags;
  final ValidateTransactionBudgetsService _validateBudgets;

  /// Creates the transaction workflow.
  const CreateTransactionService({
    required Clock clock,
    required CreateTransactionUseCase createTransaction,
    required ValidateTransactionAssetSemanticsService validateAssets,
    required ValidateTransactionAllocationsService validateAllocations,
    required ValidateTransactionTagsService validateTags,
    required ValidateTransactionBudgetsService validateBudgets,
  }) : _clock = clock, // ignore: prefer_initializing_formals
       _createTransaction = // ignore: prefer_initializing_formals
           createTransaction,
       _validateAssets = validateAssets, // ignore: prefer_initializing_formals
       _validateAllocations = // ignore: prefer_initializing_formals
           validateAllocations,
       _validateTags = validateTags, // ignore: prefer_initializing_formals
       _validateBudgets = // ignore: prefer_initializing_formals
           validateBudgets;

  /// Creates, validates, and persists a transaction from [command].
  Future<Result<Transaction, BaseFailure>> call(
    CreateTransactionCommand command,
  ) async {
    final transaction = Transaction.create(
      kind: command.kind,
      merchantId: command.merchantId,
      effectiveAt: command.effectiveAt,
      description: command.description,
      note: command.note,
      state: command.state,
      tagIds: command.tagIds,
      splits: command.splits,
      ledgerEntries: command.ledgerEntries,
      clock: _clock,
    );

    final assetResult = await _validateAssets(transaction);

    if (assetResult case final Failure<BaseFailure> failure) {
      return failure;
    }

    final allocationResult = await _validateAllocations(transaction);

    if (allocationResult case final Failure<BaseFailure> failure) {
      return failure;
    }

    final tagResult = await _validateTags.validateForCreate(transaction.tagIds);

    if (tagResult case final Failure<BaseFailure> failure) {
      return failure;
    }

    final budgetResult = await _validateBudgets(transaction);

    if (budgetResult case final Failure<BaseFailure> failure) {
      return failure;
    }

    final createResult = await _createTransaction(transaction);

    return createResult.when<Result<Transaction, BaseFailure>>(
      success: (_) => Success(transaction),
      failure: (failure) => failure,
    );
  }
}
