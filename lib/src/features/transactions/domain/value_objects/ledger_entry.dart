import 'package:axiom/src/core/domain/mappers/decimal_mapper.dart';
import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/transactions/domain/enums/ledger_entry_role.dart';
import 'package:dart_mappable/dart_mappable.dart';
import 'package:decimal/decimal.dart';

part 'ledger_entry.mapper.dart';

/// Describes one account-balance impact caused by a transaction.
///
/// A ledger entry associates a transaction amount with exactly one affected
/// account and records that amount in the transaction, account, and valuation
/// representations.
///
/// [transactionAmount] preserves the asset and quantity involved in the
/// financial event.
///
/// [accountAmount] describes the resulting account balance impact.
///
/// [valuationAmount] represents the same economic impact in the user's
/// configured valuation currency.
///
/// ## Fee semantics
///
/// Fees are ordinary ledger impacts with [LedgerEntryRole.fee].
///
/// A fixed fee is represented by a fee entry with [feePercentage] equal to
/// `null`. The asset stored in [transactionAmount] is the asset actually used
/// to pay the fee and may be any supported asset.
///
/// A percentage fee additionally stores the percentage originally entered by
/// the user in [feePercentage]. The ledger amounts remain the authoritative
/// resolved monetary impact. This is necessary because percentage fees may
/// require rounding, account conversion, or valuation conversion before being
/// persisted.
///
/// A percentage value uses percentage units:
///
/// - `1` means 1%;
/// - `0.25` means 0.25%;
/// - `12.5` means 12.5%.
///
/// Fee ledger entries are always outgoing.
///
/// ## Invariants
///
/// - [accountId] is valid.
/// - All monetary amounts satisfy [AssetAmount] invariants.
/// - All three monetary representations have the same direction.
/// - Equal assets must carry equal quantities.
/// - A fee entry is outgoing.
/// - [feePercentage] may only be supplied for a fee entry.
/// - [feePercentage], when supplied, is greater than zero.
@MappableClass(includeCustomMappers: [DecimalMapper()])
final class LedgerEntry with LedgerEntryMappable {
  /// Account affected by this entry.
  final AccountId accountId;

  /// Amount in the asset directly involved in this ledger movement.
  final AssetAmount transactionAmount;

  /// Balance impact in the affected account's representation.
  final AssetAmount accountAmount;

  /// Economic value in the configured valuation currency.
  final AssetAmount valuationAmount;

  /// Economic purpose of this entry.
  final LedgerEntryRole role;

  /// Percentage originally used to express this fee.
  ///
  /// `null` means either:
  ///
  /// - this is not a fee entry; or
  /// - this is a fixed-amount fee.
  ///
  /// The resolved [transactionAmount], [accountAmount], and [valuationAmount]
  /// remain authoritative for financial calculations.
  final Decimal? feePercentage;

  /// Creates a ledger entry.
  LedgerEntry({
    required this.accountId,
    required this.transactionAmount,
    required this.accountAmount,
    required this.valuationAmount,
    required this.role,
    this.feePercentage,
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

    _validateFeeSemantics();
  }

  /// Creates a fixed-amount fee.
  ///
  /// [transactionAmount] may use any supported asset.
  factory LedgerEntry.fixedFee({
    required AccountId accountId,
    required AssetAmount transactionAmount,
    required AssetAmount accountAmount,
    required AssetAmount valuationAmount,
  }) {
    return LedgerEntry(
      accountId: accountId,
      transactionAmount: transactionAmount,
      accountAmount: accountAmount,
      valuationAmount: valuationAmount,
      role: LedgerEntryRole.fee,
    );
  }

  /// Creates a fee that was entered as a percentage.
  ///
  /// The supplied monetary amounts are the already-resolved financial impact.
  /// [percentage] preserves how the fee was expressed by the user.
  factory LedgerEntry.percentageFee({
    required AccountId accountId,
    required AssetAmount transactionAmount,
    required AssetAmount accountAmount,
    required AssetAmount valuationAmount,
    required Decimal percentage,
  }) {
    return LedgerEntry(
      accountId: accountId,
      transactionAmount: transactionAmount,
      accountAmount: accountAmount,
      valuationAmount: valuationAmount,
      role: LedgerEntryRole.fee,
      feePercentage: percentage,
    );
  }

  /// Whether this is a fee originally expressed as a percentage.
  bool get isPercentageFee =>
      role == LedgerEntryRole.fee && feePercentage != null;

  /// Whether this is a fee expressed directly as an asset amount.
  bool get isFixedFee => role == LedgerEntryRole.fee && feePercentage == null;

  void _validateFeeSemantics() {
    if (feePercentage != null && role != LedgerEntryRole.fee) {
      throw ArgumentError.value(
        feePercentage,
        'feePercentage',
        'A fee percentage may only be attached to a fee ledger entry.',
      );
    }

    if (role != LedgerEntryRole.fee) {
      return;
    }

    if (!transactionAmount.isOutgoing) {
      throw ArgumentError.value(
        transactionAmount,
        'transactionAmount',
        'A fee ledger entry must be outgoing.',
      );
    }

    final percentage = feePercentage;

    if (percentage != null && percentage <= Decimal.zero) {
      throw ArgumentError.value(
        percentage,
        'feePercentage',
        'Fee percentage must be greater than zero.',
      );
    }
  }

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

  static void _validateSameAssetAmount({
    required AssetAmount transactionAmount,
    required AssetAmount accountAmount,
    required AssetAmount valuationAmount,
  }) {
    final usesAccountAsset = transactionAmount.assetId == accountAmount.assetId;

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
