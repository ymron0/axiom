import 'package:axiom/src/application/services/validate_transaction_allocations_service.dart';
import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/ports/clock/clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/application/commands/create_transaction_command.dart';
import 'package:axiom/src/features/transactions/application/use_cases/create_transaction_use_case.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';

/// Creates a transaction after validating its cross-feature allocations.
final class CreateTransactionService {
  /// Creates a transaction workflow using the supplied dependencies.
  const CreateTransactionService({
    required Clock clock,
    required CreateTransactionUseCase createTransaction,
    required ValidateTransactionAllocationsService validateAllocations,
  }) : _clock = clock, // ignore: prefer_initializing_formals
       _createTransaction = // ignore: prefer_initializing_formals
           createTransaction,
       _validateAllocations = // ignore: prefer_initializing_formals
           validateAllocations;

  final Clock _clock;
  final CreateTransactionUseCase _createTransaction;
  final ValidateTransactionAllocationsService _validateAllocations;

  /// Creates and persists a transaction from [command].
  ///
  /// Returns failures from allocation validation or transaction persistence.
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
      splits: command.splits,
      ledgerEntries: command.ledgerEntries,
      clock: _clock,
    );
    final validationResult = await _validateAllocations(transaction);

    if (validationResult case final Failure<BaseFailure> failure) {
      return failure;
    }

    final createResult = await _createTransaction(transaction);

    return createResult.when<Result<Transaction, BaseFailure>>(
      success: (_) => Success(transaction),
      failure: (failure) => failure,
    );
  }
}
