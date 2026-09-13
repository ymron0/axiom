import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/custodian_id.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/custodians/domain/value_objects/account_valuation.dart';
import 'package:axiom/src/features/custodians/domain/value_objects/custodian_aggregation.dart';
import 'package:decimal/decimal.dart';

/// Aggregates already-valued accounts into one custodian total.
///
/// Each [AccountValuation] contains:
///
/// - the account's current balance in its own denomination asset; and
/// - the equivalent value in the app's valuation currency.
///
/// Only [AccountValuation.valuationAmount] participates in the custodian total.
/// Native account amounts cannot be aggregated because accounts belonging to
/// the same custodian may use different assets.
///
/// ## Example
///
/// ```text
/// Account A
///   accountAmount:     EUR 1,000
///   valuationAmount:   CHF   935
///
/// Account B
///   accountAmount:     USD   500
///   valuationAmount:   CHF   400
///
/// Custodian total:     CHF 1,335
/// ```
///
/// ## Invariants
///
/// Every supplied [AccountValuation]:
///
/// - must belong to [custodianId];
/// - must express its valuation amount in [valuationCurrencyId]; and
/// - must represent a distinct account.
///
/// An empty collection is valid and produces a zero-valued incoming
/// [AssetAmount] in [valuationCurrencyId].
///
/// ## Contract
///
/// This calculator is synchronous, deterministic, and stateless.
///
/// It performs no repository access, exchange-rate lookup, settings lookup,
/// application orchestration, or presentation work.
final class CustodianAggregationCalculator {
  /// Creates a custodian aggregation calculator.
  const CustodianAggregationCalculator();

  /// Calculates the total current value of [accountValuations].
  ///
  /// Throws an [ArgumentError] when:
  ///
  /// - an account belongs to a different custodian;
  /// - a valuation amount uses a different valuation currency; or
  /// - the same account appears more than once.
  CustodianAggregation calculate({
    required CustodianId custodianId,
    required AssetId valuationCurrencyId,
    required Iterable<AccountValuation> accountValuations,
  }) {
    var total = AssetAmount.incoming(
      assetId: valuationCurrencyId,
      amount: Decimal.zero,
    );

    var accountCount = 0;

    final seenAccountIds = <AccountId>{};

    for (final valuation in accountValuations) {
      _validateCustodian(
        expectedCustodianId: custodianId,
        valuation: valuation,
      );

      _validateValuationCurrency(
        expectedValuationCurrencyId: valuationCurrencyId,
        valuation: valuation,
      );

      _validateUniqueAccount(
        seenAccountIds: seenAccountIds,
        valuation: valuation,
      );

      total = total.add(valuation.valuationAmount);
      accountCount++;
    }

    return CustodianAggregation(
      custodianId: custodianId,
      total: total,
      accountCount: accountCount,
    );
  }

  /// Ensures that every supplied account belongs to the custodian being
  /// aggregated.
  void _validateCustodian({
    required CustodianId expectedCustodianId,
    required AccountValuation valuation,
  }) {
    if (valuation.custodianId != expectedCustodianId) {
      throw ArgumentError.value(
        valuation.custodianId,
        'accountValuations',
        'Every account valuation must belong to the aggregated custodian.',
      );
    }
  }

  /// Ensures that all account values can safely participate in one sum.
  ///
  /// Native account assets may differ, but the valuation amounts must all use
  /// the same app valuation currency.
  void _validateValuationCurrency({
    required AssetId expectedValuationCurrencyId,
    required AccountValuation valuation,
  }) {
    if (valuation.valuationAmount.assetId !=
        expectedValuationCurrencyId) {
      throw ArgumentError.value(
        valuation.valuationAmount.assetId,
        'accountValuations',
        'Every valuation amount must use the aggregation valuation currency.',
      );
    }
  }

  /// Prevents an account from contributing to the custodian total more than
  /// once.
  void _validateUniqueAccount({
    required Set<AccountId> seenAccountIds,
    required AccountValuation valuation,
  }) {
    if (!seenAccountIds.add(valuation.accountId)) {
      throw ArgumentError.value(
        valuation.accountId,
        'accountValuations',
        'An account cannot appear more than once in a custodian aggregation.',
      );
    }
  }
}