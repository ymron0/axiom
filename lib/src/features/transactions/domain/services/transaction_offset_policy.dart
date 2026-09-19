import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/core/identity/ids/jar_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/enums/ledger_entry_role.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_kind.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_state.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_failure.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_offset_exceeds_available_amount_failure.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_offset_validation_failure.dart';
import 'package:decimal/decimal.dart';

/// Validates relationships between original transactions and their offsets.
///
/// An offset is an ordinary transaction representing value that economically
/// reduces another transaction.
///
/// Examples include:
///
/// - merchant refunds;
/// - reimbursements from another person; and
/// - cashback received after a purchase.
///
/// ## Monetary semantics
///
/// Offset capacity is measured using the primary ledger entry's
/// `transactionAmount`.
///
/// The original and every offset must therefore use the same transaction asset.
///
/// Account amounts are deliberately not used because a reimbursement may enter
/// a different account from the account used by the original purchase.
///
/// Valuation amounts are deliberately not used because valuation rates may
/// differ between the original transaction and a later offset.
///
/// ## Direction semantics
///
/// An expense may only be offset by an income transaction.
///
/// An income may only be offset by an expense transaction.
///
/// Transfers and balance corrections cannot act as original offset targets.
///
/// ## Allocation semantics
///
/// When the original transaction contains allocation splits, offsets may only
/// use allocation-target combinations already present on the original.
///
/// Cumulative offset value for an allocation target cannot exceed the original
/// value allocated to that target.
///
/// An unallocated original transaction cannot acquire allocations indirectly
/// through an offset.
///
/// ## History semantics
///
/// An offset cannot itself become the original of another offset.
///
/// Relationship identity is validated here but relationship immutability is
/// enforced by the repository during update.
final class TransactionOffsetPolicy {
  /// Creates a stateless transaction-offset policy.
  const TransactionOffsetPolicy();

  /// Validates [offset] against [original] and previously persisted offsets.
  ///
  /// [existingOffsets] must contain all active offsets already associated with
  /// [original], excluding [offset] itself.
  ///
  /// Returns [Success] when the relationship and cumulative amounts are valid.
  /// Otherwise returns a [TransactionFailure] describing the first invalid
  /// condition. This method does not throw for expected validation failures.
  ///
  /// This method performs no persistence. The repository must execute this
  /// validation and the corresponding write in the same atomic database
  /// transaction when preventing concurrent over-offsets.
  Result<void, TransactionFailure> validateNewOffset({
    required Transaction original,
    required Transaction offset,
    required Iterable<Transaction> existingOffsets,
  }) {
    final originalValidation = validateOriginal(original);

    if (originalValidation case final Failure<TransactionFailure> failure) {
      return failure;
    }

    final offsetValidation = _validateOffsetShape(
      original: original,
      offset: offset,
    );

    if (offsetValidation case final Failure<TransactionFailure> failure) {
      return failure;
    }

    final validatedExistingOffsets = <Transaction>[];

    for (final existingOffset in existingOffsets) {
      final validation = _validateOffsetShape(
        original: original,
        offset: existingOffset,
      );

      if (validation case final Failure<TransactionFailure> failure) {
        return failure;
      }

      validatedExistingOffsets.add(existingOffset);
    }

    final originalAmount = _primaryAmount(original);

    var cumulativeAmount = _primaryAmount(offset).amount;

    for (final existingOffset in validatedExistingOffsets) {
      cumulativeAmount += _primaryAmount(existingOffset).amount;
    }

    if (cumulativeAmount > originalAmount.amount) {
      return TransactionOffsetExceedsAvailableAmountFailure(
        message:
            'Cumulative offsets exceed the original transaction amount. '
            'Original: ${originalAmount.amount}; '
            'requested cumulative offset: $cumulativeAmount.',
      );
    }

    return _validateAllocationCapacity(
      original: original,
      offsets: <Transaction>[...validatedExistingOffsets, offset],
    );
  }

  /// Validates whether [original] may receive transaction offsets.
  ///
  /// An original must be active and actual, must be an expense or income, and
  /// must have a known positive primary transaction amount. Returns [Success]
  /// when those conditions hold; otherwise returns a [TransactionFailure].
  Result<void, TransactionFailure> validateOriginal(Transaction original) {
    if (original.isDeleted) {
      return const TransactionOffsetValidationFailure(
        message: 'A deleted transaction cannot receive offsets.',
      );
    }

    if (original.isOffset) {
      return const TransactionOffsetValidationFailure(
        message: 'An offset transaction cannot itself receive offsets.',
      );
    }

    if (original.state != TransactionState.actual) {
      return const TransactionOffsetValidationFailure(
        message: 'Only actual transactions can receive offsets.',
      );
    }

    if (original.kind != TransactionKind.expense &&
        original.kind != TransactionKind.income) {
      return const TransactionOffsetValidationFailure(
        message: 'Only expense and income transactions can receive offsets.',
      );
    }

    final amount = _primaryAmount(original);

    if (amount.isUnknownAmount) {
      return const TransactionOffsetValidationFailure(
        message:
            'A transaction with an unknown primary amount cannot receive '
            'offsets.',
      );
    }

    if (amount.amount <= Decimal.zero) {
      return const TransactionOffsetValidationFailure(
        message:
            'A transaction must have a positive primary amount before it can '
            'receive offsets.',
      );
    }

    return const Success(null);
  }

  Result<void, TransactionFailure> _validateAllocationCapacity({
    required Transaction original,
    required List<Transaction> offsets,
  }) {
    if (original.splits.isEmpty) {
      final introducesAllocation = offsets.any(
        (offset) => offset.splits.isNotEmpty,
      );

      if (introducesAllocation) {
        return const TransactionOffsetValidationFailure(
          message:
              'An offset cannot introduce allocation targets when the original '
              'transaction has no allocations.',
        );
      }

      return const Success(null);
    }

    final capacities = <({CategoryId? categoryId, JarId? jarId}), Decimal>{};

    for (final split in original.splits) {
      final key = (categoryId: split.categoryId, jarId: split.jarId);

      capacities[key] =
          (capacities[key] ?? Decimal.zero) + split.transactionAmount.amount;
    }

    final consumed = <({CategoryId? categoryId, JarId? jarId}), Decimal>{};

    for (final offset in offsets) {
      if (offset.splits.isEmpty) {
        return const TransactionOffsetValidationFailure(
          message:
              'An offset of an allocated transaction must preserve allocation '
              'information.',
        );
      }

      for (final split in offset.splits) {
        final key = (categoryId: split.categoryId, jarId: split.jarId);

        final capacity = capacities[key];

        if (capacity == null) {
          return const TransactionOffsetValidationFailure(
            message:
                'An offset uses an allocation target combination that does not '
                'exist on the original transaction.',
          );
        }

        final newConsumed =
            (consumed[key] ?? Decimal.zero) + split.transactionAmount.amount;

        if (newConsumed > capacity) {
          return TransactionOffsetExceedsAvailableAmountFailure(
            message:
                'Cumulative offset allocation exceeds the amount allocated '
                'to the corresponding target on the original transaction.',
          );
        }

        consumed[key] = newConsumed;
      }
    }

    return const Success(null);
  }

  Result<void, TransactionFailure> _validateOffsetShape({
    required Transaction original,
    required Transaction offset,
  }) {
    if (offset.isDeleted) {
      return const TransactionOffsetValidationFailure(
        message: 'A deleted transaction cannot be used as an offset.',
      );
    }

    final relationship = offset.offset;

    if (relationship == null) {
      return const TransactionOffsetValidationFailure(
        message: 'The transaction does not contain an offset relationship.',
      );
    }

    if (offset.id == original.id) {
      return const TransactionOffsetValidationFailure(
        message: 'A transaction cannot offset itself.',
      );
    }

    if (relationship.originalTransactionId != original.id) {
      return const TransactionOffsetValidationFailure(
        message:
            'The offset relationship does not reference the supplied original '
            'transaction.',
      );
    }

    if (offset.state != TransactionState.actual) {
      return const TransactionOffsetValidationFailure(
        message: 'An offset transaction must be actual.',
      );
    }

    final expectedKind = original.kind == TransactionKind.expense
        ? TransactionKind.income
        : TransactionKind.expense;

    if (offset.kind != expectedKind) {
      return TransactionOffsetValidationFailure(
        message:
            'Offset transaction kind ${offset.kind.name} does not reverse '
            'original transaction kind ${original.kind.name}.',
      );
    }

    if (offset.effectiveAt.isBefore(original.effectiveAt)) {
      return const TransactionOffsetValidationFailure(
        message:
            'An offset cannot be effective before the original transaction.',
      );
    }

    final originalAmount = _primaryAmount(original);
    final offsetAmount = _primaryAmount(offset);

    if (offsetAmount.isUnknownAmount) {
      return const TransactionOffsetValidationFailure(
        message: 'An offset transaction cannot have an unknown amount.',
      );
    }

    if (offsetAmount.amount <= Decimal.zero) {
      return const TransactionOffsetValidationFailure(
        message: 'An offset transaction amount must be greater than zero.',
      );
    }

    if (offsetAmount.assetId != originalAmount.assetId) {
      return const TransactionOffsetValidationFailure(
        message:
            'An offset must use the same transaction asset as the original '
            'transaction.',
      );
    }

    return const Success(null);
  }

  static AssetAmount _primaryAmount(Transaction transaction) {
  return transaction.ledgerEntries
      .singleWhere((entry) => entry.role == LedgerEntryRole.primary)
      .transactionAmount;
}
}
