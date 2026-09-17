import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/transactions/domain/enums/recurrence_amount_completion.dart';
import 'package:dart_mappable/dart_mappable.dart';
import 'package:decimal/decimal.dart';

part 'recurrence_amount_end.mapper.dart';

/// Defines cumulative monetary termination for a recurring transaction series.
///
/// The recurrence continues until generated occurrence amounts reach or exceed
/// [targetAmount].
///
/// ## Target semantics
///
/// [targetAmount] represents the cumulative primary transaction amount that the
/// recurrence intends to generate.
///
/// For an expense recurrence the target is normally outgoing:
///
/// ```text
/// Pay CHF 1,000 in total.
/// ```
///
/// For an income recurrence the target is normally incoming:
///
/// ```text
/// Receive CHF 5,000 in total.
/// ```
///
/// The target therefore retains both the asset and direction through
/// [AssetAmount].
///
/// ## Final-occurrence semantics
///
/// [completion] determines what happens when the remaining target is smaller
/// than the next normal occurrence.
///
/// Given:
///
/// ```text
/// target:      CHF 1,000
/// accumulated: CHF   960
/// normal:      CHF   120
/// ```
///
/// [RecurrenceAmountCompletion.fullOccurrence] produces CHF 120.
///
/// [RecurrenceAmountCompletion.exactTarget] produces CHF 40.
///
/// ## Progress semantics
///
/// Progress is based on amounts resolved from the recurrence definition,
/// including recurrence exceptions.
///
/// A skipped occurrence contributes nothing.
///
/// A replacement occurrence contributes the primary amount of its replacement
/// transaction template.
///
/// Generated transactions themselves remain ordinary transactions and are not
/// inspected by this value object.
///
/// ## Invariants
///
/// - [targetAmount] must be known.
/// - [targetAmount] must be strictly greater than zero.
/// - values compared with this target must use the same asset.
/// - values compared with this target must use the same direction.
/// - values compared with this target must be known.
///
/// This value object decides the primary amount of the next occurrence. It does
/// not rebuild transaction ledger entries, splits, account-currency values, or
/// valuation-currency values. That work requires financial context and belongs
/// to the occurrence-generation workflow.
@MappableClass()
final class RecurrenceAmountEnd with RecurrenceAmountEndMappable {
  /// Cumulative amount at which this recurrence terminates.
  final AssetAmount targetAmount;

  /// Policy applied when the remaining target is smaller than a normal
  /// occurrence.
  final RecurrenceAmountCompletion completion;

  /// Creates an amount-based recurrence termination rule.
  ///
  /// Throws an [ArgumentError] when [targetAmount] is unknown or not strictly
  /// positive.
  @MappableConstructor()
  RecurrenceAmountEnd({required this.targetAmount, required this.completion}) {
    if (targetAmount.isUnknownAmount) {
      throw ArgumentError.value(
        targetAmount,
        'targetAmount',
        'Recurrence target amount must be known.',
      );
    }

    if (targetAmount.amount <= Decimal.zero) {
      throw ArgumentError.value(
        targetAmount,
        'targetAmount',
        'Recurrence target amount must be greater than zero.',
      );
    }
  }

  /// Whether [accumulatedAmount] has reached this target.
  ///
  /// A value greater than the target is considered reached. This is necessary
  /// for [RecurrenceAmountCompletion.fullOccurrence], whose final occurrence
  /// may intentionally overshoot the target.
  ///
  /// Throws an [ArgumentError] when [accumulatedAmount] is unknown or uses a
  /// different asset or direction.
  bool isReachedBy(AssetAmount accumulatedAmount) {
    _validateComparable(accumulatedAmount, parameterName: 'accumulatedAmount');

    return accumulatedAmount.amount >= targetAmount.amount;
  }

  /// Returns the amount that should be used for the next occurrence.
  ///
  /// [accumulatedAmount] is the cumulative amount contributed by previously
  /// resolved occurrences.
  ///
  /// [normalOccurrenceAmount] is the primary transaction amount the next
  /// occurrence would normally use after recurrence exceptions have been
  /// applied.
  ///
  /// Returns `null` when the target has already been reached.
  ///
  /// When the normal occurrence does not exceed the remaining target, it is
  /// returned unchanged.
  ///
  /// When it exceeds the remaining target:
  ///
  /// - [RecurrenceAmountCompletion.fullOccurrence] returns the full normal
  ///   amount;
  /// - [RecurrenceAmountCompletion.exactTarget] returns only the remaining
  ///   amount.
  ///
  /// Throws an [ArgumentError] when either supplied amount is unknown or uses
  /// a different asset or direction from [targetAmount].
  AssetAmount? resolveNextAmount({
    required AssetAmount accumulatedAmount,
    required AssetAmount normalOccurrenceAmount,
  }) {
    _validateComparable(accumulatedAmount, parameterName: 'accumulatedAmount');

    _validateComparable(
      normalOccurrenceAmount,
      parameterName: 'normalOccurrenceAmount',
    );

    if (isReachedBy(accumulatedAmount)) {
      return null;
    }

    final remaining = targetAmount.amount - accumulatedAmount.amount;

    if (normalOccurrenceAmount.amount <= remaining) {
      return normalOccurrenceAmount;
    }

    return switch (completion) {
      RecurrenceAmountCompletion.fullOccurrence => normalOccurrenceAmount,

      RecurrenceAmountCompletion.exactTarget => AssetAmount(
        assetId: targetAmount.assetId,
        amount: remaining,
        direction: targetAmount.direction,
      ),
    };
  }

  /// Whether applying [occurrenceAmount] would complete this amount target.
  ///
  /// [accumulatedAmount] represents progress before the occurrence.
  ///
  /// This method does not modify either amount.
  ///
  /// Throws an [ArgumentError] when either amount is unknown or uses a
  /// different asset or direction from [targetAmount].
  bool completesWith({
    required AssetAmount accumulatedAmount,
    required AssetAmount occurrenceAmount,
  }) {
    _validateComparable(accumulatedAmount, parameterName: 'accumulatedAmount');

    _validateComparable(occurrenceAmount, parameterName: 'occurrenceAmount');

    return accumulatedAmount.amount + occurrenceAmount.amount >=
        targetAmount.amount;
  }

  /// Returns the remaining amount before the target is reached.
  ///
  /// Returns zero once the target has already been reached or exceeded.
  ///
  /// Throws an [ArgumentError] when [accumulatedAmount] is unknown or uses a
  /// different asset or direction.
  AssetAmount remainingAfter(AssetAmount accumulatedAmount) {
    _validateComparable(accumulatedAmount, parameterName: 'accumulatedAmount');

    final remaining = targetAmount.amount - accumulatedAmount.amount;

    return AssetAmount(
      assetId: targetAmount.assetId,
      amount: remaining > Decimal.zero ? remaining : Decimal.zero,
      direction: targetAmount.direction,
    );
  }

  void _validateComparable(
    AssetAmount amount, {
    required String parameterName,
  }) {
    if (amount.isUnknownAmount) {
      throw ArgumentError.value(
        amount,
        parameterName,
        'Recurrence amount progress must use known amounts.',
      );
    }

    if (amount.assetId != targetAmount.assetId) {
      throw ArgumentError.value(
        amount,
        parameterName,
        'Recurrence amount progress must use the target asset.',
      );
    }

    if (amount.direction != targetAmount.direction) {
      throw ArgumentError.value(
        amount,
        parameterName,
        'Recurrence amount progress must use the target direction.',
      );
    }
  }
}
