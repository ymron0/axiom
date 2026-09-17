import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:decimal/decimal.dart';

/// Calculates the signed balance of a jar from allocation amounts.
///
/// The caller is responsible for selecting the allocations belonging to the
/// jar and deciding which transactions are financially relevant.
///
/// This calculator performs only pure monetary aggregation.
///
/// ## Semantics
///
/// Incoming allocations increase the balance.
///
/// Outgoing allocations decrease the balance.
///
/// A positive net balance is represented as an incoming [AssetAmount].
///
/// A negative net balance is represented as an outgoing [AssetAmount] whose
/// [AssetAmount.amount] contains the positive magnitude.
///
/// An exact zero balance is canonically represented as an incoming zero amount.
///
/// Consequently, calculation is independent of allocation iteration order,
/// including when opposing allocations cancel exactly.
///
/// ## Invariants
///
/// Every allocation:
///
/// - must use [valuationCurrencyId];
/// - must contain a known amount.
///
/// ## Precision
///
/// All arithmetic uses [Decimal]. No conversion through binary floating point,
/// implicit rounding, or presentation formatting occurs here.
///
/// ## Contract
///
/// No repository access, transaction filtering, settings lookup, exchange-rate
/// lookup, or presentation behavior belongs here.
final class JarBalanceCalculator {
  /// Creates a stateless jar balance calculator.
  const JarBalanceCalculator();

  /// Calculates the signed net balance of [allocationAmounts].
  ///
  /// Throws an [ArgumentError] when an allocation:
  ///
  /// - uses an asset other than [valuationCurrencyId]; or
  /// - contains an unknown amount.
  AssetAmount calculate({
    required AssetId valuationCurrencyId,
    required Iterable<AssetAmount> allocationAmounts,
  }) {
    var signedBalance = Decimal.zero;

    for (final allocationAmount in allocationAmounts) {
      _validateAllocation(
        valuationCurrencyId: valuationCurrencyId,
        allocationAmount: allocationAmount,
      );

      signedBalance += allocationAmount.isIncoming
          ? allocationAmount.amount
          : -allocationAmount.amount;
    }

    if (signedBalance < Decimal.zero) {
      return AssetAmount.outgoing(
        assetId: valuationCurrencyId,
        amount: signedBalance.abs(),
      );
    }

    return AssetAmount.incoming(
      assetId: valuationCurrencyId,
      amount: signedBalance,
    );
  }

  void _validateAllocation({
    required AssetId valuationCurrencyId,
    required AssetAmount allocationAmount,
  }) {
    if (allocationAmount.assetId != valuationCurrencyId) {
      throw ArgumentError.value(
        allocationAmount.assetId,
        'allocationAmounts',
        'Every jar allocation must use the valuation currency.',
      );
    }

    if (allocationAmount.isUnknownAmount) {
      throw ArgumentError.value(
        allocationAmount,
        'allocationAmounts',
        'Jar allocations cannot contain unknown valuation amounts.',
      );
    }
  }
}