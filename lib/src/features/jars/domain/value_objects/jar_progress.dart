import 'package:axiom/src/core/domain/value_objects/calendar_date.dart';
import 'package:axiom/src/core/identity/ids/jar_id.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/jars/domain/value_objects/jar_target.dart';
import 'package:decimal/decimal.dart';

/// Derived financial state of one jar at a particular calendar date.
///
/// A jar does not persist any of these values. They are derived from
/// transaction allocations and the target configuration effective on [asOf].
///
/// ## Semantics
///
/// [balance] is the signed net value currently allocated to the jar:
///
/// - incoming allocations increase it;
/// - outgoing allocations decrease it.
///
/// [savedAmount] is the non-negative portion of that balance used for goal
/// progress.
///
/// [remainingAmount] and [progressRatio] are only available when a target is
/// effective on [asOf].
///
/// [progressRatio] is normalized to the inclusive range `0` through `1`.
/// Overfunding therefore produces `1`, while [isTargetReached] distinguishes
/// whether the target has actually been reached.
///
/// ## Contract
///
/// All monetary values belonging to this result use the same asset.
final class JarProgress {
  /// The jar whose financial state is represented.
  final JarId jarId;

  /// Calendar date on which target configuration was resolved.
  final CalendarDate asOf;

  /// Signed net balance allocated to the jar.
  final AssetAmount balance;

  /// Non-negative amount currently saved toward the target.
  final AssetAmount savedAmount;

  /// Target effective on [asOf], or `null` when no target applies.
  final JarTarget? target;

  /// Amount still required to reach [target].
  ///
  /// `null` when no target applies.
  final AssetAmount? remainingAmount;

  /// Goal completion ratio between `0` and `1`.
  ///
  /// `null` when no target applies.
  final Decimal? progressRatio;

  /// Whether the effective target has been reached or exceeded.
  ///
  /// Always `false` when no target applies.
  final bool isTargetReached;

  /// Creates derived jar progress.
  JarProgress({
    required this.jarId,
    required this.asOf,
    required this.balance,
    required this.savedAmount,
    required this.target,
    required this.remainingAmount,
    required this.progressRatio,
    required this.isTargetReached,
  }) {
    if (balance.isUnknownAmount) {
      throw ArgumentError.value(
        balance,
        'balance',
        'Jar balance cannot be unknown.',
      );
    }

    if (savedAmount.isUnknownAmount) {
      throw ArgumentError.value(
        savedAmount,
        'savedAmount',
        'Saved amount cannot be unknown.',
      );
    }

    if (savedAmount.assetId != balance.assetId) {
      throw ArgumentError.value(
        savedAmount,
        'savedAmount',
        'Saved amount must use the same asset as the jar balance.',
      );
    }

    if (!savedAmount.isIncoming) {
      throw ArgumentError.value(
        savedAmount,
        'savedAmount',
        'Saved amount must be represented as an incoming magnitude.',
      );
    }

    if (target == null) {
      if (remainingAmount != null ||
          progressRatio != null ||
          isTargetReached) {
        throw ArgumentError(
          'A jar without an effective target cannot have target progress.',
        );
      }

      return;
    }

    if (target!.amount.assetId != balance.assetId) {
      throw ArgumentError.value(
        target,
        'target',
        'Jar target must use the same asset as the derived balance.',
      );
    }

    if (remainingAmount == null) {
      throw ArgumentError(
        'Remaining amount is required when a target is effective.',
      );
    }

    if (remainingAmount!.assetId != balance.assetId) {
      throw ArgumentError.value(
        remainingAmount,
        'remainingAmount',
        'Remaining amount must use the same asset as the jar balance.',
      );
    }

    if (!remainingAmount!.isIncoming) {
      throw ArgumentError.value(
        remainingAmount,
        'remainingAmount',
        'Remaining amount must be represented as an incoming magnitude.',
      );
    }

    if (progressRatio == null) {
      throw ArgumentError(
        'Progress ratio is required when a target is effective.',
      );
    }

    if (progressRatio! < Decimal.zero || progressRatio! > Decimal.one) {
      throw ArgumentError.value(
        progressRatio,
        'progressRatio',
        'Progress ratio must be between 0 and 1.',
      );
    }
  }

  /// Whether a target is effective on [asOf].
  bool get hasTarget => target != null;
}