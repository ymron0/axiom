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
import 'package:decimal/decimal.dart';

/// Materializes recurrence occurrences as ordinary planned transactions.
///
/// Generated transactions deliberately contain no transaction-series identity
/// or recurrence metadata. The series remains only the definition used to
/// derive those transactions.
///
/// ## Range semantics
///
/// [scheduledFrom] is inclusive and [scheduledUntil] is exclusive.
///
/// The range applies to the original recurrence slots produced by the series
/// recurrence rule. A recurrence exception may move the effective transaction
/// date outside this range; the occurrence still belongs to the selected
/// scheduled slot and is therefore generated.
///
/// ## Generation horizon
///
/// Generated planned transactions are subject to a rolling maximum horizon of
/// two calendar years from the current local calendar date.
///
/// For example, when the current date is September 21, 2026, an occurrence
/// scheduled on September 21, 2028 may be generated, but an occurrence
/// scheduled on September 22, 2028 may not.
///
/// [generationHorizon] may further restrict generation to:
///
/// - the next eligible occurrence;
/// - one rolling calendar year; or
/// - the maximum two rolling calendar years.
///
/// The horizon limits materialization only. It never changes or truncates the
/// underlying [TransactionSeries].
///
/// [scheduledUntil] remains a caller-requested upper bound. The effective
/// generation boundary is always the earliest applicable boundary.
///
/// ## Amount termination
///
/// Cumulative amount progress is evaluated from recurrence index zero, even
/// when [scheduledFrom] starts later. This is necessary because the amount
/// available for a final occurrence depends on all earlier recurrence slots.
///
/// Skipped occurrences contribute no amount progress.
///
/// Replacement occurrences contribute the primary amount of their resolved
/// replacement template.
///
/// Exact-target completion resizes the final occurrence through
/// [ResizePlannedTransactionTemplateService].
///
/// ## Persistence
///
/// This service does not persist generated transactions.
///
/// Re-running generation creates new ordinary transaction identities. Because
/// those transactions intentionally contain no recurrence identity, callers
/// must decide when a generated batch is persisted and must not treat repeated
/// generation as an idempotent persistence operation.
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
  ///
  /// [generationHorizon] should normally come from the current application
  /// settings.
  ///
  /// Even when [generationHorizon] is [PlannedTransactionGenerationHorizon.twoYears],
  /// generation can never exceed two rolling calendar years from today.
  ///
  /// Returns [TransactionSeriesGenerationDisabledFailure] when [series] is
  /// archived or deleted.
  ///
  /// Template materialization failures are propagated unchanged.
  ///
  /// Throws [ArgumentError] when [scheduledUntil] is not after
  /// [scheduledFrom].
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
      final scheduledOn = series.recurrenceRule.occurrenceAt(occurrenceIndex);

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
