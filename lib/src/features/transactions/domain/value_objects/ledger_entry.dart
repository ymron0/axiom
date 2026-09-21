import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/transactions/domain/enums/ledger_entry_role.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/fee_expression.dart';
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
/// Every fee has an explicit [feeExpression] describing how the fee was
/// originally entered:
///
/// - [PercentageFeeExpression] for percentage fees;
/// - [AssetAmountFeeExpression] for fees entered directly as an asset amount.
///
/// The expression is metadata describing the original user input.
///
/// The resolved [transactionAmount], [accountAmount], and [valuationAmount]
/// remain authoritative for financial calculations.
///
/// For an [AssetAmountFeeExpression], the expression amount must exactly match
/// [transactionAmount].
///
/// Percentage fees may resolve to a monetary amount requiring rounding,
/// account conversion, or valuation conversion.
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
/// - A fee entry always has a fee expression.
/// - A non-fee entry never has a fee expression.
/// - An asset-amount fee expression exactly matches [transactionAmount].
@MappableClass()
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

  /// How this fee was originally expressed by the user.
  ///
  /// This is always non-null for fee entries and always null for non-fee
  /// entries.
  final FeeExpression? feeExpression;

  /// Creates a ledger entry.
  ///
  /// For backward source compatibility, directly constructing a fee entry
  /// without [feeExpression] interprets [transactionAmount] as the original
  /// asset-amount fee expression.
  LedgerEntry({
    required this.accountId,
    required this.transactionAmount,
    required this.accountAmount,
    required this.valuationAmount,
    required this.role,
    FeeExpression? feeExpression,
  }) : feeExpression = _resolveFeeExpression(
         role: role,
         transactionAmount: transactionAmount,
         feeExpression: feeExpression,
       ) {
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

    _validateFeeExpression();
  }

  /// Creates a fee expressed directly as an asset amount.
  ///
  /// [transactionAmount] represents both:
  ///
  /// - the original fee expression; and
  /// - the resolved transaction-asset impact.
  ///
  /// The fee asset may be any supported asset.
  factory LedgerEntry.assetAmountFee({
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
      feeExpression: AssetAmountFeeExpression(amount: transactionAmount),
    );
  }

  /// Compatibility alias for [LedgerEntry.assetAmountFee].
  factory LedgerEntry.fixedFee({
    required AccountId accountId,
    required AssetAmount transactionAmount,
    required AssetAmount accountAmount,
    required AssetAmount valuationAmount,
  }) {
    return LedgerEntry.assetAmountFee(
      accountId: accountId,
      transactionAmount: transactionAmount,
      accountAmount: accountAmount,
      valuationAmount: valuationAmount,
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
      feeExpression: PercentageFeeExpression(percentage: percentage),
    );
  }

  /// Whether this is a fee originally expressed as a percentage.
  bool get isPercentageFee => feeExpression is PercentageFeeExpression;

  /// Whether this is a fee originally expressed as an asset amount.
  bool get isAssetAmountFee => feeExpression is AssetAmountFeeExpression;

  /// Compatibility alias for [isAssetAmountFee].
  bool get isFixedFee => isAssetAmountFee;

  /// Percentage originally used to express this fee.
  ///
  /// Returns null when the fee was expressed as an asset amount or when this
  /// is not a fee entry.
  ///
  /// This getter exists for compatibility with existing callers. New code
  /// should generally inspect [feeExpression] directly.
  Decimal? get feePercentage {
    return switch (feeExpression) {
      PercentageFeeExpression(:final percentage) => percentage,
      _ => null,
    };
  }

  /// Asset amount originally used to express this fee.
  ///
  /// Returns null when the fee was expressed as a percentage or when this is
  /// not a fee entry.
  AssetAmount? get feeAssetAmount {
    return switch (feeExpression) {
      AssetAmountFeeExpression(:final amount) => amount,
      _ => null,
    };
  }

  void _validateFeeExpression() {
    final expression = feeExpression;

    if (role != LedgerEntryRole.fee) {
      return;
    }

    if (expression == null) {
      // coverage:ignore-start
      throw StateError('A fee ledger entry must have a fee expression.');
      // coverage:ignore-end
    }

    if (expression case AssetAmountFeeExpression(:final amount)) {
      final matchesTransactionAmount =
          amount.assetId == transactionAmount.assetId &&
          amount.amount == transactionAmount.amount &&
          amount.direction == transactionAmount.direction;

      if (!matchesTransactionAmount) {
        throw ArgumentError.value(
          expression,
          'feeExpression',
          'An asset-amount fee expression must exactly match the fee '
              'transaction amount.',
        );
      }
    }
  }

  static FeeExpression? _resolveFeeExpression({
    required LedgerEntryRole role,
    required AssetAmount transactionAmount,
    required FeeExpression? feeExpression,
  }) {
    if (role != LedgerEntryRole.fee) {
      if (feeExpression != null) {
        throw ArgumentError.value(
          feeExpression,
          'feeExpression',
          'A fee expression may only be attached to a fee ledger entry.',
        );
      }

      return null;
    }

    if (!transactionAmount.isOutgoing) {
      throw ArgumentError.value(
        transactionAmount,
        'transactionAmount',
        'A fee ledger entry must be outgoing.',
      );
    }

    return feeExpression ?? AssetAmountFeeExpression(amount: transactionAmount);
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
