import 'package:axiom/src/application/services/validate_transaction_allocations_service.dart';
import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/ports/clock/clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/application/commands/create_transaction_offset_command.dart';
import 'package:axiom/src/features/transactions/application/use_cases/create_transaction_offset_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/get_transaction_by_id_use_case.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_kind.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_state.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_failure.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_not_found_failure.dart';
import 'package:axiom/src/features/transactions/domain/services/transaction_offset_policy.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/transaction_offset.dart';

/// Creates refunds, reimbursements, cashback, and other transaction offsets.
///
/// This is the cross-feature orchestration boundary intended to be called by
/// presentation code.
///
/// It coordinates:
///
/// - original transaction lookup;
/// - transaction-offset domain validation;
/// - transaction construction;
/// - category and jar allocation validation; and
/// - atomic offset persistence.
///
/// The final cumulative amount check intentionally remains inside the
/// repository transaction so concurrent offset creation cannot overrun the
/// original transaction amount.
final class CreateTransactionOffsetService {
  /// Creates the transaction-offset workflow.
  const CreateTransactionOffsetService({
    required Clock clock,
    required GetTransactionByIdUseCase getTransactionById,
    required CreateTransactionOffsetUseCase createTransactionOffset,
    required ValidateTransactionAllocationsService validateAllocations,
    required TransactionOffsetPolicy offsetPolicy,
  }) : _clock = clock, // ignore: prefer_initializing_formals
       _getTransactionById = // ignore: prefer_initializing_formals
           getTransactionById,
       _createTransactionOffset = // ignore: prefer_initializing_formals
           createTransactionOffset,
       _validateAllocations = // ignore: prefer_initializing_formals
           validateAllocations,
       _offsetPolicy = // ignore: prefer_initializing_formals
           offsetPolicy;

  final Clock _clock;
  final GetTransactionByIdUseCase _getTransactionById;
  final CreateTransactionOffsetUseCase _createTransactionOffset;
  final ValidateTransactionAllocationsService _validateAllocations;
  final TransactionOffsetPolicy _offsetPolicy;

  /// Creates one offset transaction from [command].
  Future<Result<Transaction, BaseFailure>> call(
    CreateTransactionOffsetCommand command,
  ) async {
    final originalResult = await _getTransactionById(
      command.originalTransactionId,
    );

    if (originalResult case final Failure<TransactionFailure> failure) {
      return failure;
    }

    final original = originalResult.valueOrNull;

    if (original == null) {
      return TransactionNotFoundFailure(
        message:
            'Original transaction ID was not found: '
            '${command.originalTransactionId.value}',
      );
    }

    final originalValidation = _offsetPolicy.validateOriginal(original);

    if (originalValidation case final Failure<TransactionFailure> failure) {
      return failure;
    }

    final offsetTransactionKind = original.kind == TransactionKind.expense
        ? TransactionKind.income
        : TransactionKind.expense;

    final transaction = Transaction.create(
      kind: offsetTransactionKind,
      merchantId: command.merchantId,
      effectiveAt: command.effectiveAt,
      description: command.description,
      note: command.note,
      state: TransactionState.actual,
      offset: TransactionOffset(
        originalTransactionId: original.id,
        kind: command.offsetKind,
      ),
      splits: command.splits,
      ledgerEntries: command.ledgerEntries,
      clock: _clock,
    );

    final localValidation = _offsetPolicy.validateNewOffset(
      original: original,
      offset: transaction,
      existingOffsets: const <Transaction>[],
    );

    if (localValidation case final Failure<TransactionFailure> failure) {
      return failure;
    }

    final allocationValidation = await _validateAllocations(transaction);

    if (allocationValidation case final Failure<BaseFailure> failure) {
      return failure;
    }

    final createResult = await _createTransactionOffset(transaction);

    return createResult.when<Result<Transaction, BaseFailure>>(
      success: (_) => Success(transaction),
      failure: (failure) => failure,
    );
  }
}
