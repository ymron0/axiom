import 'dart:collection';

import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/custodian_id.dart';
import 'package:decimal/decimal.dart';

/// Summarizes the balances of accounts owned by one custodian.
///
/// ## Ownership
///
/// [custodianId] identifies the custodian represented by this summary.
///
/// [accountCount] is the number of accounts included in the summary.
///
/// [balancesByAsset] contains the combined signed account balance for each
/// account-denomination asset represented by those accounts.
///
/// ## Currency semantics
///
/// Balances belonging to different assets are never added together.
///
/// For example, CHF and EUR account balances remain separate entries in
/// [balancesByAsset]. Currency conversion is deliberately outside the scope of
/// this value object.
///
/// ## Immutability
///
/// The supplied balance map is defensively copied and exposed through an
/// unmodifiable view.
///
/// ## Contract
///
/// This value object contains already-derived summary data. It performs no
/// repository access, balance calculation, exchange-rate resolution, or
/// presentation formatting.
final class CustodianSummary {
  /// Creates an immutable custodian summary.
  CustodianSummary({
    required this.custodianId,
    required this.accountCount,
    required Map<AssetId, Decimal> balancesByAsset,
  }) : balancesByAsset = UnmodifiableMapView(
         Map<AssetId, Decimal>.of(balancesByAsset),
       ) {
    if (accountCount < 0) {
      throw ArgumentError.value(
        accountCount,
        'accountCount',
        'Account count cannot be negative.',
      );
    }
  }

  /// The custodian represented by this summary.
  final CustodianId custodianId;

  /// Number of accounts included in this summary.
  final int accountCount;

  /// Combined signed account balances grouped by denomination asset.
  final Map<AssetId, Decimal> balancesByAsset;

  /// Returns the combined balance for [assetId].
  ///
  /// Returns [Decimal.zero] when no account in the summary uses [assetId].
  Decimal balanceFor(AssetId assetId) {
    return balancesByAsset[assetId] ?? Decimal.zero;
  }
}
