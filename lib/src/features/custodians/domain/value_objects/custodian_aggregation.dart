import 'package:axiom/src/core/identity/ids/custodian_id.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';

/// The aggregated current value of the accounts belonging to one custodian.
///
/// This is derived financial state and is therefore not persisted on the
/// [Custodian] entity.
///
/// [total] is expressed entirely in the app's valuation currency. Individual
/// accounts may use different denomination assets, so their native account
/// amounts cannot be added directly.
///
/// For example:
///
/// ```text
/// EUR account:   EUR 1,000 -> CHF   935
/// USD account:   USD   500 -> CHF   400
/// CHF account:   CHF 2,000 -> CHF 2,000
///                           ----------
/// Custodian total           CHF 3,335
/// ```
///
/// ## Invariants
///
/// - [total] must be a known [AssetAmount].
/// - [accountCount] cannot be negative.
///
/// The aggregation calculator additionally guarantees that every contributing
/// account belongs to [custodianId] and uses the same valuation currency.
final class CustodianAggregation {
  /// Creates a custodian aggregation.
  ///
  /// Throws an [ArgumentError] when [total] is unknown or [accountCount] is
  /// negative.
  CustodianAggregation({
    required this.custodianId,
    required this.total,
    required this.accountCount,
  }) {
    if (total.isUnknownAmount) {
      throw ArgumentError.value(
        total,
        'total',
        'Custodian aggregation requires a known total.',
      );
    }

    if (accountCount < 0) {
      throw ArgumentError.value(
        accountCount,
        'accountCount',
        'Custodian aggregation account count cannot be negative.',
      );
    }
  }

  /// The custodian represented by this aggregation.
  final CustodianId custodianId;

  /// The signed aggregate value of all included accounts.
  ///
  /// [AssetAmount.assetId] identifies the app's valuation currency.
  ///
  /// An incoming total represents positive net value. An outgoing total
  /// represents negative net value.
  final AssetAmount total;

  /// The number of distinct accounts included in [total].
  ///
  /// Zero-valued accounts are included in this count because they still belong
  /// to the custodian aggregation.
  final int accountCount;
}