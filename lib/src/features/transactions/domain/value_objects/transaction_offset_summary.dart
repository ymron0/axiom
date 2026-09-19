import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/transaction_id.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:decimal/decimal.dart';

/// Summarizes the economic effect of offsets applied to one transaction.
///
/// The original transaction remains unchanged.
///
/// This value object exposes derived amounts suitable for transaction-detail
/// presentation.
///
/// For example:
///
/// ```text
/// Original expense       CHF 100
/// Reimbursement          CHF  50
/// Net cost               CHF  50
/// ```
///
/// All amounts represent magnitudes in [assetId].
final class TransactionOffsetSummary {
  /// Original transaction being summarized.
  final TransactionId transactionId;

  /// Transaction asset in which summary amounts are expressed.
  final AssetId assetId;

  /// Original transaction amount before offsets.
  final Decimal grossAmount;

  /// Cumulative merchant-refund amount.
  final Decimal refundAmount;

  /// Cumulative reimbursement amount.
  final Decimal reimbursementAmount;

  /// Cumulative cashback amount.
  final Decimal cashbackAmount;

  /// Active offset transactions contributing to this summary.
  final List<Transaction> offsets;

  /// Creates an immutable transaction-offset summary.
  TransactionOffsetSummary({
    required this.transactionId,
    required this.assetId,
    required this.grossAmount,
    required this.refundAmount,
    required this.reimbursementAmount,
    required this.cashbackAmount,
    required List<Transaction> offsets,
  }) : offsets = List.unmodifiable(offsets) {
    if (grossAmount <= Decimal.zero) {
      throw ArgumentError.value(
        grossAmount,
        'grossAmount',
        'Gross amount must be greater than zero.',
      );
    }

    if (refundAmount < Decimal.zero) {
      throw ArgumentError.value(
        refundAmount,
        'refundAmount',
        'Refund amount cannot be negative.',
      );
    }

    if (reimbursementAmount < Decimal.zero) {
      throw ArgumentError.value(
        reimbursementAmount,
        'reimbursementAmount',
        'Reimbursement amount cannot be negative.',
      );
    }

    if (cashbackAmount < Decimal.zero) {
      throw ArgumentError.value(
        cashbackAmount,
        'cashbackAmount',
        'Cashback amount cannot be negative.',
      );
    }

    if (totalOffsetAmount > grossAmount) {
      throw ArgumentError.value(
        totalOffsetAmount,
        'offsets',
        'Total offset amount cannot exceed gross amount.',
      );
    }

    for (final offset in this.offsets) {
      if (offset.offset?.originalTransactionId != transactionId) {
        throw ArgumentError.value(
          offset,
          'offsets',
          'Every offset must reference the summarized transaction.',
        );
      }
    }
  }

  /// Whether at least one active offset exists.
  bool get hasOffsets => offsets.isNotEmpty;

  /// Whether the original amount has been fully offset.
  bool get isFullyOffset => totalOffsetAmount == grossAmount;

  /// Whether some but not all original value has been offset.
  bool get isPartiallyOffset =>
      totalOffsetAmount > Decimal.zero && totalOffsetAmount < grossAmount;

  /// Remaining economic value after active offsets.
  Decimal get netAmount => grossAmount - totalOffsetAmount;

  /// Total economic value offset from the original transaction.
  Decimal get totalOffsetAmount =>
      refundAmount + reimbursementAmount + cashbackAmount;
}
