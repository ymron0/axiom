import 'package:axiom/src/application/failures/transaction_occurrence_operation_failure.dart';
import 'package:axiom/src/application/services/generate_planned_transactions_service.dart';
import 'package:axiom/src/core/domain/value_objects/calendar_date.dart';
import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/identity/ids/transaction_id.dart';
import 'package:axiom/src/core/ports/clock/clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/settings/domain/enums/planned_transaction_generation_horizon.dart';
import 'package:axiom/src/features/transactions/application/use_cases/create_transaction_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/delete_transaction_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/get_transaction_by_id_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/get_transaction_series_by_id_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/restore_transaction_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/update_transaction_series_use_case.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction_series.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_occurrence_deletion_mode.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_failure.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_not_found_failure.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_series_failure.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_series_not_found_failure.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/recurrence_exception.dart';

/// Coordinates deletion of one generated transaction-series occurrence.
///
/// Three behaviors are supported:
///
/// - `skip`: delete the materialized transaction and permanently suppress its
///   recurrence slot;
/// - `regenerate`: delete the materialized transaction and create a fresh
///   transaction for the same recurrence slot;
/// - `skipAndAppend`: suppress the original slot and extend a finite series by
///   one recurrence slot.
///
/// The `skipAndAppend` mode changes the recurrence definition but deliberately
/// does not immediately materialize an occurrence outside the currently active
/// generation horizon.
///
/// The normal future-generation workflow creates that appended occurrence when
/// it enters the configured generation horizon.
final class DeleteTransactionOccurrenceService {
  final GetTransactionByIdUseCase _getTransactionById;
  final GetTransactionSeriesByIdUseCase _getSeriesById;
  final UpdateTransactionSeriesUseCase _updateSeries;
  final DeleteTransactionUseCase _deleteTransaction;
  final RestoreTransactionUseCase _restoreTransaction;
  final CreateTransactionUseCase _createTransaction;
  final GeneratePlannedTransactionsService _generate;
  final Clock _clock;

  /// Creates the occurrence-deletion coordinator.
  const DeleteTransactionOccurrenceService({
    required GetTransactionByIdUseCase getTransactionById,
    required GetTransactionSeriesByIdUseCase getSeriesById,
    required UpdateTransactionSeriesUseCase updateSeries,
    required DeleteTransactionUseCase deleteTransaction,
    required RestoreTransactionUseCase restoreTransaction,
    required CreateTransactionUseCase createTransaction,
    required GeneratePlannedTransactionsService generate,
    required Clock clock,
  }) : _getTransactionById = // ignore: prefer_initializing_formals
           getTransactionById,
       _getSeriesById = getSeriesById, // ignore: prefer_initializing_formals
       _updateSeries = updateSeries, // ignore: prefer_initializing_formals
       _deleteTransaction = // ignore: prefer_initializing_formals
           deleteTransaction,
       _restoreTransaction = // ignore: prefer_initializing_formals
           restoreTransaction,
       _createTransaction = // ignore: prefer_initializing_formals
           createTransaction,
       _generate = generate, // ignore: prefer_initializing_formals
       _clock = clock; // ignore: prefer_initializing_formals

  /// Deletes occurrence [id] according to [mode].
  Future<Result<void, BaseFailure>> call({
    required TransactionId id,
    required TransactionOccurrenceDeletionMode mode,
  }) async {
    final transactionResult = await _getTransactionById(id);

    if (transactionResult case final Failure<TransactionFailure> failure) {
      return failure;
    }

    final transaction = transactionResult.valueOrNull;

    if (transaction == null) {
      return TransactionNotFoundFailure(
        message: 'Transaction ID was not found: ${id.value}',
      );
    }

    final origin = transaction.recurrenceOrigin;

    if (origin == null) {
      return TransactionOccurrenceOperationFailure(
        message:
            'Transaction is not a generated recurrence occurrence: '
            '${transaction.id.value}',
      );
    }

    final seriesResult = await _getSeriesById(origin.seriesId);

    if (seriesResult case final Failure<TransactionSeriesFailure> failure) {
      return failure;
    }

    final series = seriesResult.valueOrNull;

    if (series == null) {
      return TransactionSeriesNotFoundFailure(
        message:
            'Transaction series ID was not found: '
            '${origin.seriesId.value}',
      );
    }

    if (!series.definesOccurrenceOn(origin.scheduledOn)) {
      return TransactionOccurrenceOperationFailure(
        message:
            'The transaction recurrence slot is not defined by its series: '
            '${origin.scheduledOn}.',
      );
    }

    return switch (mode) {
      TransactionOccurrenceDeletionMode.skip => _skip(
        transaction: transaction,
        series: series,
        extendsSeries: false,
      ),
      TransactionOccurrenceDeletionMode.regenerate => _regenerate(
        transaction: transaction,
        series: series,
      ),
      TransactionOccurrenceDeletionMode.skipAndAppend => _skip(
        transaction: transaction,
        series: series,
        extendsSeries: true,
      ),
    };
  }

  Future<Result<void, BaseFailure>> _skip({
    required Transaction transaction,
    required TransactionSeries series,
    required bool extendsSeries,
  }) async {
    final origin = transaction.recurrenceOrigin!;

    final updatedSeries = _withSkip(
      series: series,
      scheduledOn: origin.scheduledOn,
      extendsSeries: extendsSeries,
    );

    final updateResult = await _updateSeries(updatedSeries);

    if (updateResult case final Failure<TransactionSeriesFailure> failure) {
      return failure;
    }

    final deleteResult = await _deleteTransaction(
      transaction.id,
      _clock.nowUtc,
    );

    if (deleteResult case final Failure<TransactionFailure> failure) {
      // Best-effort rollback of the recurrence definition when deletion fails.
      await _updateSeries(series);

      return failure;
    }

    return const Success(null);
  }

  Future<Result<void, BaseFailure>> _regenerate({
    required Transaction transaction,
    required TransactionSeries series,
  }) async {
    final origin = transaction.recurrenceOrigin!;

    final scheduledUntil = CalendarDate.fromDateTime(
      origin.scheduledOn.toDateTimeUtc().add(const Duration(days: 1)),
    );

    // Generate the replacement before deleting the persisted transaction.
    //
    // If the series can no longer materialize this slot, the existing
    // transaction therefore remains untouched.
    final generationResult = _generate(
      series: series,
      scheduledFrom: origin.scheduledOn,
      scheduledUntil: scheduledUntil,
      generationHorizon: PlannedTransactionGenerationHorizon.nextOccurrence,
    );

    if (generationResult case final Failure<TransactionFailure> failure) {
      return failure;
    }

    final generated = generationResult.valueOrNull!;

    if (generated.length != 1) {
      return TransactionOccurrenceOperationFailure(
        message:
            'The recurrence slot could not produce exactly one replacement '
            'transaction.',
      );
    }

    final replacement = generated.single;

    final deleteResult = await _deleteTransaction(
      transaction.id,
      _clock.nowUtc,
    );

    if (deleteResult case final Failure<TransactionFailure> failure) {
      return failure;
    }

    final deletedSnapshot = deleteResult.valueOrNull!;

    final createResult = await _createTransaction(replacement);

    if (createResult case final Failure<TransactionFailure> failure) {
      // Best-effort rollback.
      //
      // The original transaction is restored if persistence of the freshly
      // generated replacement fails.
      await _restoreTransaction(deletedSnapshot);

      return failure;
    }

    return const Success(null);
  }

  TransactionSeries _withSkip({
    required TransactionSeries series,
    required CalendarDate scheduledOn,
    required bool extendsSeries,
  }) {
    final exceptions = <RecurrenceException>[
      for (final exception in series.exceptions)
        if (exception.scheduledOn.compareTo(scheduledOn) != 0) exception,
      RecurrenceException.skip(
        scheduledOn: scheduledOn,
        extendsSeries: extendsSeries,
      ),
    ];

    return TransactionSeries(
      id: series.id,
      template: series.template,
      recurrenceRule: series.recurrenceRule,
      exceptions: exceptions,
      archivedAt: series.archivedAt,
      deletedAt: series.deletedAt,
      createdAt: series.createdAt,
      modifiedAt: _clock.nowUtc,
      entityVersion: series.entityVersion,
    );
  }
}
