import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/ledger_entry.dart';
import 'package:decimal/decimal.dart';

/// Derives an account's per-asset positions from ledger entries.
///
/// ## Semantics
///
/// [LedgerEntry.transactionAmount] represents the asset movement belonging to
/// the affected account.
///
/// Entries are grouped by transaction-amount asset. Incoming amounts increase
/// the position and outgoing amounts decrease it.
///
/// A resulting zero position is omitted.
///
/// Negative positions are retained as outgoing [AssetAmount] instances.
///
/// ## Invariants
///
/// Matching ledger entries must contain known transaction amounts. Unknown
/// amounts represent incomplete financial state and cause [calculate] to throw
/// an [ArgumentError].
///
/// Entries belonging to another account are ignored.
///
/// ## Ordering
///
/// Results are ordered deterministically by [AssetId.value].
///
/// ## Contract
///
/// This calculator is synchronous, deterministic, stateless, and performs no
/// repository, persistence, rate-resolution, or presentation work.
final class AccountAssetBalanceCalculator {
  /// Creates an account asset-balance calculator.
  const AccountAssetBalanceCalculator();

  /// Returns the non-zero per-asset balances held by [accountId].
  List<AssetAmount> calculate({
    required AccountId accountId,
    required Iterable<LedgerEntry> ledgerEntries,
  }) {
    final balances = <AssetId, Decimal>{};

    for (final entry in ledgerEntries) {
      if (entry.accountId != accountId) {
        continue;
      }

      final amount = entry.transactionAmount;

      if (amount.isUnknownAmount) {
        throw ArgumentError.value(
          amount,
          'ledgerEntries',
          'An account asset balance cannot be derived from an unknown '
              'transaction amount.',
        );
      }

      balances.update(
        amount.assetId,
        (current) => current + _toSignedAmount(amount),
        ifAbsent: () => _toSignedAmount(amount),
      );
    }

    final result = <AssetAmount>[];

    for (final entry in balances.entries) {
      if (entry.value == Decimal.zero) {
        continue;
      }

      result.add(
        _fromSignedAmount(assetId: entry.key, signedAmount: entry.value),
      );
    }

    result.sort(
      (left, right) => left.assetId.value.compareTo(right.assetId.value),
    );

    return List.unmodifiable(result);
  }

  Decimal _toSignedAmount(AssetAmount amount) {
    return amount.isIncoming ? amount.amount : -amount.amount;
  }

  AssetAmount _fromSignedAmount({
    required AssetId assetId,
    required Decimal signedAmount,
  }) {
    if (signedAmount < Decimal.zero) {
      return AssetAmount.outgoing(assetId: assetId, amount: signedAmount.abs());
    }

    return AssetAmount.incoming(assetId: assetId, amount: signedAmount);
  }
}
