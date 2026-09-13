import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/ledger_entry.dart';
import 'package:decimal/decimal.dart';

/// Derives an account's signed balance from ledger entries.
///
/// ## Invariants
///
/// Every entry matching [accountId] must express its [LedgerEntry.accountAmount]
/// in [denominationAssetId]. A mismatch is malformed domain input and causes
/// [calculate] to throw an [ArgumentError]. Entries for other accounts are
/// ignored and are not denomination-validated.
///
/// ## Semantics
///
/// Incoming account amounts increase the balance and outgoing account amounts
/// decrease it. No matching entries produce [Decimal.zero]. Transaction and
/// valuation amounts do not participate in the calculation.
///
/// ## Contract
///
/// The calculation is synchronous, stateless, and performs no repository or
/// presentation work.
final class AccountBalanceCalculator {
  /// Creates an account balance calculator.
  const AccountBalanceCalculator();

  /// Calculates the signed balance for [accountId].
  ///
  /// Throws an [ArgumentError] when a matching entry's account amount does not
  /// use [denominationAssetId].
  Decimal calculate({
    required AccountId accountId,
    required AssetId denominationAssetId,
    required Iterable<LedgerEntry> ledgerEntries,
  }) {
    var balance = Decimal.zero;

    for (final entry in ledgerEntries) {
      if (entry.accountId != accountId) {
        continue;
      }

      final accountAmount = entry.accountAmount;
      if (accountAmount.assetId != denominationAssetId) {
        throw ArgumentError.value(
          accountAmount.assetId,
          'ledgerEntries',
          'A matching ledger entry must use the account denomination asset.',
        );
      }

      balance = accountAmount.isIncoming
          ? balance + accountAmount.amount
          : balance - accountAmount.amount;
    }

    return balance;
  }
}
