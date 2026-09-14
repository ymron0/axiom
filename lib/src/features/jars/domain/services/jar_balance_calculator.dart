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
/// An empty collection produces a zero-valued incoming amount.
///
/// ## Invariants
///
/// Every allocation:
///
/// - must use [valuationCurrencyId];
/// - must contain a known amount.
///
/// ## Contract
///
/// No repository access, transaction filtering, settings lookup, exchange-rate
/// lookup, or presentation behavior belongs here.
final class JarBalanceCalculator {
  /// Creates a stateless jar balance calculator.
  const JarBalanceCalculator();

  /// Calculates the signed net balance of [allocationAmounts].
  AssetAmount calculate({
    required AssetId valuationCurrencyId,
    required Iterable<AssetAmount> allocationAmounts,
  }) {
    var balance = AssetAmount.incoming(
      assetId: valuationCurrencyId,
      amount: Decimal.zero,
    );

    for (final allocationAmount in allocationAmounts) {
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

      balance = balance.add(allocationAmount);
    }

    return balance;
  }
}