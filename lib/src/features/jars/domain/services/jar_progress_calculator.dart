import 'package:axiom/src/core/domain/value_objects/calendar_date.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/jars/domain/entities/jar.dart';
import 'package:axiom/src/features/jars/domain/value_objects/jar_progress.dart';
import 'package:decimal/decimal.dart';

/// Calculates saved amount and target progress from an already-derived jar
/// balance.
///
/// ## Semantics
///
/// A positive jar balance represents money currently saved.
///
/// A negative jar balance represents a deficit. The displayed saved amount is
/// therefore zero, while the deficit increases the amount required to reach
/// the target.
///
/// Progress is normalized to the range `0..1`.
///
/// Examples for a target of CHF 1,000:
///
/// ```text
/// balance      saved      remaining    progress
/// CHF 400      CHF 400    CHF 600      0.4
/// CHF 1000     CHF 1000   CHF 0        1
/// CHF 1200     CHF 1200   CHF 0        1
/// CHF -100     CHF 0      CHF 1100     0
/// ```
///
/// The calculator performs no persistence or transaction lookup.
final class JarProgressCalculator {
  /// Creates a stateless progress calculator.
  const JarProgressCalculator();

  /// Calculates financial progress for [jar] on [asOf].
  JarProgress calculate({
    required Jar jar,
    required AssetAmount balance,
    required CalendarDate asOf,
  }) {
    if (balance.isUnknownAmount) {
      throw ArgumentError.value(
        balance,
        'balance',
        'Jar balance cannot be unknown.',
      );
    }

    final signedBalance = balance.isIncoming
        ? balance.amount
        : -balance.amount;

    final savedMagnitude = signedBalance > Decimal.zero
        ? signedBalance
        : Decimal.zero;

    final savedAmount = AssetAmount.incoming(
      assetId: balance.assetId,
      amount: savedMagnitude,
    );

    final target = jar.targetAt(asOf);

    if (target == null) {
      return JarProgress(
        jarId: jar.id,
        asOf: asOf,
        balance: balance,
        savedAmount: savedAmount,
        target: null,
        remainingAmount: null,
        progressRatio: null,
        isTargetReached: false,
      );
    }

    if (target.amount.assetId != balance.assetId) {
      throw ArgumentError.value(
        target.amount.assetId,
        'balance',
        'Jar target and derived jar balance must use the same asset.',
      );
    }

    final targetMagnitude = target.amount.amount;

    final rawRemaining = targetMagnitude - signedBalance;

    final remainingMagnitude = rawRemaining > Decimal.zero
        ? rawRemaining
        : Decimal.zero;

    final remainingAmount = AssetAmount.incoming(
      assetId: balance.assetId,
      amount: remainingMagnitude,
    );

    final isTargetReached = signedBalance >= targetMagnitude;

    final Decimal progressRatio;

    if (savedMagnitude <= Decimal.zero) {
      progressRatio = Decimal.zero;
    } else if (savedMagnitude >= targetMagnitude) {
      progressRatio = Decimal.one;
    } else {
      progressRatio = (savedMagnitude / targetMagnitude).toDecimal(
        scaleOnInfinitePrecision: 6,
      );
    }

    return JarProgress(
      jarId: jar.id,
      asOf: asOf,
      balance: balance,
      savedAmount: savedAmount,
      target: target,
      remainingAmount: remainingAmount,
      progressRatio: progressRatio,
      isTargetReached: isTargetReached,
    );
  }
}