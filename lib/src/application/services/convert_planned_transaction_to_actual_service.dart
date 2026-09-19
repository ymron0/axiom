import 'package:axiom/src/application/services/update_transaction_service.dart';
import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/identity/ids/transaction_id.dart';
import 'package:axiom/src/core/ports/clock/clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/application/use_cases/get_transaction_by_id_use_case.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_state.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_already_actual_failure.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_failure.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_not_found_failure.dart';

/// Converts one persisted planned transaction into an actual transaction.
///
/// The operation preserves transaction identity. It does not create a second
/// transaction and does not establish any link back to a transaction series.
///
/// The current transaction snapshot is loaded before conversion so the
/// workflow never actualizes stale caller-owned state.
///
/// Cross-feature allocation validation is performed through
/// [UpdateTransactionService] before the actual snapshot is persisted.
///
/// ## Effective time
///
/// When [effectiveAt] is supplied, it becomes the actual transaction's
/// effective instant.
///
/// When omitted, the current [Clock] instant is used. This makes a simple
/// "mark as actual now" interaction possible while still supporting historical
/// entry.
///
/// ## UI state
///
/// This service exposes its operation through [Result]. Presentation code can
/// therefore represent:
///
/// - loading while the returned future is unresolved;
/// - success from the returned [Transaction]; and
/// - recoverable error state from the returned [BaseFailure].
///
/// No Flutter or accessibility concerns are embedded in this application
/// service.
final class ConvertPlannedTransactionToActualService {
  final Clock _clock;
  final GetTransactionByIdUseCase _getTransactionById;
  final UpdateTransactionService _updateTransaction;

  /// Creates a planned-to-actual workflow.
  const ConvertPlannedTransactionToActualService({
    required Clock clock,
    required GetTransactionByIdUseCase getTransactionById,
    required UpdateTransactionService updateTransaction,
  }) : _clock = clock, // ignore: prefer_initializing_formals
       _getTransactionById = // ignore: prefer_initializing_formals
           getTransactionById,
       _updateTransaction = // ignore: prefer_initializing_formals
           updateTransaction;

  /// Converts the planned transaction identified by [id] to actual.
  Future<Result<Transaction, BaseFailure>> call({
    required TransactionId id,
    DateTime? effectiveAt,
  }) async {
    final lookupResult = await _getTransactionById(id);

    if (lookupResult case final Failure<TransactionFailure> failure) {
      return failure;
    }

    final existing = lookupResult.valueOrNull;

    if (existing == null) {
      return TransactionNotFoundFailure(
        message: 'Transaction ID was not found: ${id.value}',
      );
    }

    if (existing.state == TransactionState.actual) {
      return TransactionAlreadyActualFailure(
        message: 'Transaction is already actual: ${id.value}',
      );
    }

    final now = _clock.nowUtc;

    final actual = Transaction(
      id: existing.id,
      kind: existing.kind,
      merchantId: existing.merchantId,
      effectiveAt: effectiveAt ?? now,
      description: existing.description,
      note: existing.note,
      state: TransactionState.actual,
      deletedAt: existing.deletedAt,
      splits: existing.splits,
      ledgerEntries: existing.ledgerEntries,
      createdAt: existing.createdAt,
      modifiedAt: now,
      entityVersion: existing.entityVersion,
    );

    final updateResult = await _updateTransaction(actual);

    if (updateResult case final Failure<BaseFailure> failure) {
      return failure;
    }

    return Success(actual);
  }
}
