import 'package:axiom/src/core/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/features/transactions/domain/enums/ledger_entry_role.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'ledger_entry.mapper.dart';

/// Describes one account-balance impact caused by a transaction.
///
/// A ledger entry associates a transaction amount with exactly one affected
/// account and records that amount in the transaction, account, and valuation
/// currencies. Account balances are derived from ledger entries rather than
/// stored directly on accounts.
///
/// [transactionAmount] describes the amount in the currency actually used for
/// the payment. [accountAmount] describes its effect in the currency of the
/// affected account.
///
/// [valuationAmount] describes the same value in the user's configured
/// valuation currency. It exists so ledger entries can be compared and
/// aggregated across transactions and accounts using different currencies.
///
/// For example, a USD 100 purchase affecting an EUR account while CHF is the
/// valuation currency can be represented as:
///
/// ```text
/// LedgerEntry.transactionAmount:  USD 100
/// LedgerEntry.accountAmount:      EUR 85.20
/// LedgerEntry.valuationAmount:    CHF 79.40
/// ```
///
/// ## Invariants
///
/// - [accountId] is a valid [AccountId].
/// - All three amounts satisfy the invariants enforced by [AssetAmount].
/// - All three amounts have the same direction.
/// - When [transactionAmount] and either [accountAmount] or [valuationAmount]
///   use the same asset, their quantities are identical.
/// - [accountAmount] must use the asset denominating the affected account.
///   Because account denomination is external context, that invariant is
///   enforced by the transaction construction/aggregate boundary rather than
///   by this value object itself.
/// - [valuationAmount] must use the app's configured valuation asset. Because the
///   configured valuation asset is external context, that invariant is
///   enforced by the transaction construction/aggregate boundary rather than
///   by this value object itself.
///
/// ## Semantics
///
/// [transactionAmount] preserves the amount and currency used for the payment.
/// [accountAmount] is the corresponding account-currency balance impact. An
/// incoming amount increases the affected account balance; an outgoing amount
/// decreases it.
///
/// [valuationAmount] is the valuation-currency equivalent of the same value. It
/// does not describe an additional balance movement.
///
/// [role] describes the economic purpose of the entry within its transaction,
/// such as the primary account impact or a fee.
///
/// ## Contract
///
/// This is a pure domain value object. It describes an account impact but does
/// not calculate, store, cache, snapshot, or persist account balances.
///
/// ```dart
/// final entry = LedgerEntry(
///   accountId: AccountId.fromString('account-123'),
///   transactionAmount: AssetAmount.outgoing(
///     assetId: usdAssetId,
///     amount: Decimal.parse('100.00'),
///   ),
///   accountAmount: AssetAmount.outgoing(
///     assetId: eurAssetId,
///     amount: Decimal.parse('85.20'),
///   ),
///   valuationAmount: AssetAmount.outgoing(
///     assetId: chfAssetId,
///     amount: Decimal.parse('79.40'),
///   ),
///   role: LedgerEntryRole.primary,
/// );
/// ```
@MappableClass()
final class LedgerEntry with LedgerEntryMappable {
  /// The account whose balance is affected by this ledger entry.
  final AccountId accountId;

  /// The amount in the currency actually used for the payment.
  ///
  /// This currency may differ from both the affected account's currency and the
  /// user's valuation currency.
  final AssetAmount transactionAmount;

  /// The balance impact in the currency of the account identified by
  /// [accountId].
  ///
  /// The account's denomination is external context. Validation that this
  /// amount uses the account's asset belongs to the domain boundary that can
  /// access the corresponding account.
  final AssetAmount accountAmount;

  /// The economic value of [transactionAmount] in the user's valuation
  /// currency.
  ///
  /// This represents the same value, not a second balance movement.
  ///
  /// The configured valuation asset is not stored on this value object.
  /// Validation that this amount uses that asset must therefore be performed
  /// by the transaction aggregate or other domain boundary that has access to
  /// the configured valuation asset identifier.
  final AssetAmount valuationAmount;

  /// The economic purpose of this ledger entry within its transaction.
  ///
  /// The role distinguishes the transaction's primary account movement from
  /// other supported ledger impacts, such as fees.
  final LedgerEntryRole role;

  /// Creates a ledger entry describing one account-balance impact.
  ///
  /// The contained [AssetAmount] instances are already responsible for their
  /// own quantity invariants. This constructor therefore validates only
  /// relationships between the three amounts that are specific to a ledger
  /// entry.
  ///
  /// Throws an [ArgumentError] if:
  ///
  /// - the amounts do not all have the same direction; or
  /// - [transactionAmount] shares an asset with [accountAmount] or
  ///   [valuationAmount], but their quantities differ.
  LedgerEntry({
    required this.accountId,
    required this.transactionAmount,
    required this.accountAmount,
    required this.valuationAmount,
    required this.role,
  }) {
    _validateDirection(
      transactionAmount: transactionAmount,
      accountAmount: accountAmount,
      valuationAmount: valuationAmount,
    );

    _validateSameAssetAmount(
      transactionAmount: transactionAmount,
      accountAmount: accountAmount,
      valuationAmount: valuationAmount,
    );
  }

  /// Ensures all representations describe the same direction of economic
  /// movement.
  ///
  /// The account and valuation amounts represent the value of
  /// [transactionAmount], so none can have an opposing direction.
  static void _validateDirection({
    required AssetAmount transactionAmount,
    required AssetAmount accountAmount,
    required AssetAmount valuationAmount,
  }) {
    if (transactionAmount.direction != accountAmount.direction) {
      throw ArgumentError.value(
        accountAmount,
        'accountAmount',
        'Account amount must have the same direction as the transaction '
            'amount.',
      );
    }

    if (transactionAmount.direction != valuationAmount.direction) {
      throw ArgumentError.value(
        valuationAmount,
        'valuationAmount',
        'Valuation amount must have the same direction as the transaction '
            'amount.',
      );
    }
  }

  /// Ensures identical assets cannot represent different quantities.
  ///
  /// If the transaction amount uses the same asset as the account or valuation
  /// amount, no conversion exists between that pair and their quantities must
  /// therefore be identical.
  ///
  /// This also naturally requires unknown amounts to agree: two `-1` values
  /// are valid, whereas an unknown amount paired with a known quantity for the
  /// same asset is rejected.
  static void _validateSameAssetAmount({
    required AssetAmount transactionAmount,
    required AssetAmount accountAmount,
    required AssetAmount valuationAmount,
  }) {
    final usesAccountAsset =
        transactionAmount.assetId == accountAmount.assetId;

    if (usesAccountAsset && transactionAmount.amount != accountAmount.amount) {
      throw ArgumentError.value(
        accountAmount,
        'accountAmount',
        'Transaction and account amounts must be equal when they use the same '
            'asset.',
      );
    }

    final usesValuationAsset =
        transactionAmount.assetId == valuationAmount.assetId;

    if (usesValuationAsset &&
        transactionAmount.amount != valuationAmount.amount) {
      throw ArgumentError.value(
        valuationAmount,
        'valuationAmount',
        'Transaction and valuation amounts must be equal when they use the '
            'same asset.',
      );
    }
  }
}
