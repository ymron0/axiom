import 'package:axiom/src/application/services/validate_transaction_allocations_service.dart';
import 'package:axiom/src/application/services/validate_transaction_tags_service.dart';
import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/ports/clock/clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/application/commands/create_transaction_command.dart';
import 'package:axiom/src/features/transactions/application/use_cases/create_transaction_use_case.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';

/// Creates a transaction after validating cross-feature references.
final class CreateTransactionService {
  final Clock _clock;
  final CreateTransactionUseCase _createTransaction;
  final ValidateTransactionAllocationsService _validateAllocations;
  final ValidateTransactionTagsService _validateTags;

  /// Creates a transaction workflow.
  const CreateTransactionService({
    required Clock clock,
    required CreateTransactionUseCase createTransaction,
    required ValidateTransactionAllocationsService validateAllocations,
    required ValidateTransactionTagsService validateTags,
  }) : _clock = clock, // ignore: prefer_initializing_formals
       _createTransaction = createTransaction, // ignore: prefer_initializing_formals
       _validateAllocations = validateAllocations, // ignore: prefer_initializing_formals
       _validateTags = validateTags; // ignore: prefer_initializing_formals

  /// Creates and persists a transaction from [command].
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

    final allocationResult = await _validateAllocations(transaction);

    if (allocationResult case final Failure<BaseFailure> failure) {
      return failure;
    }

    final tagResult = await _validateTags.validateForCreate(
      transaction.tagIds,
    );

    if (tagResult case final Failure<BaseFailure> failure) {
      return failure;
    }

    final createResult = await _createTransaction(transaction);

    return createResult.when<Result<Transaction, BaseFailure>>(
      success: (_) => Success(transaction),
      failure: (failure) => failure,
    );
  }
}