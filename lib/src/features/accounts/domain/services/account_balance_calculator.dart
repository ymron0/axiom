import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/ledger_entry.dart';
import 'package:decimal/decimal.dart';

/// Derives an account's signed balance from ledger entries.
///
/// ## Invariants
///
/// Every entry matching [accountId]:
///
/// - must express its [LedgerEntry.accountAmount] in
///   [denominationAssetId]; and
/// - must contain a known account amount.
///
/// Violations represent malformed or incomplete domain input and cause
/// [calculate] to throw an [ArgumentError].
///
/// Entries belonging to other accounts are ignored completely and are not
/// denomination- or amount-validated.
///
/// ## Semantics
///
/// Only [LedgerEntry.accountAmount] participates in account-balance
/// calculation.
///
/// Incoming account amounts increase the balance. Outgoing account amounts
/// decrease it.
///
/// Transaction amounts and valuation amounts do not participate in the
/// calculation.
///
/// When no ledger entries match [accountId], the balance is [Decimal.zero].
///
/// ## Precision
///
/// Calculation uses [Decimal] exclusively. No binary floating-point conversion
/// or rounding is performed by this service.
///
/// ## Contract
///
/// The calculation is synchronous, deterministic, stateless, and performs no
/// repository, persistence, conversion, or presentation work.
final class AccountBalanceCalculator {
  /// Creates an account balance calculator.
  const AccountBalanceCalculator();

  /// Calculates the signed balance for [accountId].
  ///
  /// Throws an [ArgumentError] when a matching ledger entry:
  ///
  /// - uses an account amount whose asset differs from
  ///   [denominationAssetId]; or
  /// - contains an unknown account amount.
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

      if (accountAmount.isUnknownAmount) {
        throw ArgumentError.value(
          accountAmount,
          'ledgerEntries',
          'A matching ledger entry must have a known account amount.',
        );
      }

      balance = accountAmount.isIncoming
          ? balance + accountAmount.amount
          : balance - accountAmount.amount;
    }

    return balance;
  }
}