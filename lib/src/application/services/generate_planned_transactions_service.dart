import 'package:axiom/src/core/domain/value_objects/calendar_date.dart';
import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/ports/clock/clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/settings/domain/enums/planned_transaction_generation_horizon.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction_series.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_state.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_series_generation_disabled_failure.dart';
import 'package:axiom/src/features/transactions/domain/services/resize_planned_transaction_template_service.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/transaction_occurrence_origin.dart';
import 'package:decimal/decimal.dart';

/// Materializes recurrence occurrences as planned transactions.
///
/// Generated transactions retain the minimum recurrence metadata needed to
/// identify their owning series and original scheduled recurrence slot.
///
/// ## Range semantics
///
/// [scheduledFrom] is inclusive and [scheduledUntil] is exclusive.
///
/// The range applies to the original scheduled recurrence slot. A recurrence
/// exception may move the effective transaction date outside this range; the
/// transaction still belongs to the original selected recurrence slot.
///
/// ## Generation horizon
///
/// Generated transactions are subject to a rolling maximum horizon of two
/// calendar years from the current local calendar date.
///
/// [generationHorizon] may further restrict generation to:
///
/// - the next eligible occurrence;
/// - one rolling calendar year; or
/// - two rolling calendar years.
///
/// The generation horizon never truncates or modifies the underlying series.
///
/// ## Skipped occurrences
///
/// Skipped occurrences materialize no transaction.
///
/// A skipped occurrence configured to extend the series increases the number
/// of available recurrence slots through [TransactionSeries.scheduledOccurrenceAt].
///
/// ## Amount termination
///
/// Amount progress is evaluated from recurrence index zero, even when
/// [scheduledFrom] starts later.
///
/// Skipped occurrences contribute no amount progress.
///
/// Exact-target completion may resize the final occurrence through
/// [ResizePlannedTransactionTemplateService].
///
/// ## Persistence
///
/// This service does not persist generated transactions.
final class GeneratePlannedTransactionsService {
  static const int _maximumGenerationHorizonYears = 2;

  final Clock _clock;
  final ResizePlannedTransactionTemplateService _resizeTemplate;

  /// Creates a planned-transaction generator.
  const GeneratePlannedTransactionsService({
    required Clock clock,
    required ResizePlannedTransactionTemplateService resizeTemplate,
  }) : _clock = clock, // ignore: prefer_initializing_formals
       _resizeTemplate = resizeTemplate; // ignore: prefer_initializing_formals

  /// Generates planned transactions for the requested scheduled range.
  Result<List<Transaction>, BaseFailure> call({
    required TransactionSeries series,
    required CalendarDate scheduledFrom,
    required CalendarDate scheduledUntil,
    PlannedTransactionGenerationHorizon generationHorizon =
        PlannedTransactionGenerationHorizon.twoYears,
  }) {
    if (!scheduledUntil.isAfter(scheduledFrom)) {
      throw ArgumentError.value(
        scheduledUntil,
        'scheduledUntil',
        'The generation range end must be after its start.',
      );
    }

    if (!series.isGenerationEnabled) {
      return TransactionSeriesGenerationDisabledFailure(
        message:
            'Transaction series generation is disabled: '
            '${series.id.value}',
      );
    }

    final effectiveScheduledUntil = _effectiveScheduledUntil(
      requestedScheduledUntil: scheduledUntil,
      generationHorizon: generationHorizon,
    );

    if (!effectiveScheduledUntil.isAfter(scheduledFrom)) {
      return const Success(<Transaction>[]);
    }

    final generated = <Transaction>[];
    final amountEnd = series.amountEnd;

    AssetAmount? accumulatedAmount;

    if (amountEnd != null) {
      accumulatedAmount = AssetAmount(
        assetId: amountEnd.targetAmount.assetId,
        amount: Decimal.zero,
        direction: amountEnd.targetAmount.direction,
      );
    }

    var occurrenceIndex = 0;

    while (true) {
      final scheduledOn = series.scheduledOccurrenceAt(occurrenceIndex);

      if (scheduledOn == null ||
          !scheduledOn.isBefore(effectiveScheduledUntil)) {
        break;
      }

      final resolvedOccurrence = series.resolveOccurrenceAt(occurrenceIndex);

      if (resolvedOccurrence == null) {
        occurrenceIndex++;
        continue;
      }

      var occurrenceTemplate = resolvedOccurrence.template;
      AssetAmount? occurrenceProgress;

      if (amountEnd != null) {
        final normalAmount = series.amountProgressFor(occurrenceTemplate);

        final resolvedAmount = series.resolveNextAmount(
          accumulatedAmount: accumulatedAmount!,
          occurrenceTemplate: occurrenceTemplate,
        );

        if (resolvedAmount == null) {
          break;
        }

        occurrenceProgress = resolvedAmount;

        if (resolvedAmount.amount != normalAmount.amount) {
          occurrenceTemplate = _resizeTemplate(
            template: occurrenceTemplate,
            primaryAmount: resolvedAmount,
          );
        }
      }

      var generatedRequestedOccurrence = false;

      if (scheduledOn.isOnOrAfter(scheduledFrom)) {
        final materialized = occurrenceTemplate.instantiate(
          effectiveAt: resolvedOccurrence.date.toDateTimeUtc(),
          state: TransactionState.planned,
          recurrenceOrigin: TransactionOccurrenceOrigin(
            seriesId: series.id,
            scheduledOn: scheduledOn,
          ),
          clock: _clock,
        );

        if (materialized.isFailure) {
          return materialized.failureOrNull!;
        }

        generated.add(materialized.valueOrNull!);
        generatedRequestedOccurrence = true;
      }

      if (amountEnd != null) {
        accumulatedAmount = AssetAmount(
          assetId: accumulatedAmount!.assetId,
          amount: accumulatedAmount.amount + occurrenceProgress!.amount,
          direction: accumulatedAmount.direction,
        );
      }

      if (generationHorizon ==
              PlannedTransactionGenerationHorizon.nextOccurrence &&
          generatedRequestedOccurrence) {
        break;
      }

      occurrenceIndex++;
    }

    return Success(List<Transaction>.unmodifiable(generated));
  }

  CalendarDate _effectiveScheduledUntil({
    required CalendarDate requestedScheduledUntil,
    required PlannedTransactionGenerationHorizon generationHorizon,
  }) {
    final hardMaximumUntil = _exclusiveAnniversaryBoundary(
      years: _maximumGenerationHorizonYears,
    );

    final preferredUntil = switch (generationHorizon) {
      PlannedTransactionGenerationHorizon.nextOccurrence => hardMaximumUntil,
      PlannedTransactionGenerationHorizon.oneYear =>
        _exclusiveAnniversaryBoundary(years: 1),
      PlannedTransactionGenerationHorizon.twoYears => hardMaximumUntil,
    };

    var effectiveUntil = requestedScheduledUntil;

    if (hardMaximumUntil.isBefore(effectiveUntil)) {
      effectiveUntil = hardMaximumUntil;
    }

    if (preferredUntil.isBefore(effectiveUntil)) {
      effectiveUntil = preferredUntil;
    }

    return effectiveUntil;
  }

  CalendarDate _exclusiveAnniversaryBoundary({required int years}) {
    final today = CalendarDate.fromDateTime(_clock.now);
    final targetYear = today.year + years;

    final lastDayOfTargetMonth = DateTime.utc(
      targetYear,
      today.month + 1,
      0,
    ).day;

    final anniversaryDay = today.day <= lastDayOfTargetMonth
        ? today.day
        : lastDayOfTargetMonth;

    final inclusiveAnniversary = CalendarDate(
      targetYear,
      today.month,
      anniversaryDay,
    );

    return CalendarDate.fromDateTime(
      inclusiveAnniversary.toDateTimeUtc().add(const Duration(days: 1)),
    );
  }
}
