import 'package:axiom/src/core/domain/entities/base/audited_entity.dart';
import 'package:axiom/src/core/domain/enums/asset_amount_direction.dart';
import 'package:axiom/src/core/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/core/identity/unique_id.dart';
import 'package:axiom/src/core/domain/validation/text_validation.dart';
import 'package:axiom/src/core/identity/ids/merchant_id.dart';
import 'package:axiom/src/features/transactions/domain/enums/ledger_entry_role.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_kind.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_state.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/ledger_entry.dart';
import 'package:axiom/src/core/identity/ids/transaction_id.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/transaction_split.dart';
import 'package:dart_mappable/dart_mappable.dart';
import 'package:decimal/decimal.dart';

part 'transaction.mapper.dart';

/// A recorded or planned financial event.
///
/// A transaction is the aggregate root for the financial effects and
/// allocations belonging to a single financial event.
///
/// The aggregate distinguishes three separate concepts:
///
/// - transaction metadata describes the financial event itself;
/// - [ledgerEntries] describe account and asset impact;
/// - [splits] describe allocation of transaction value to domain concepts such
///   as budgets, categories, or jars.
///
/// A [LedgerEntry] therefore changes or describes an account position, while a
/// [TransactionSplit] does not. A split only assigns part of the transaction
/// value to one or more allocation targets.
///
/// Individual [LedgerEntry] and [TransactionSplit] instances enforce their own
/// local invariants. This aggregate enforces invariants involving collections
/// of those objects or relationships between them.
///
/// ## Invariants
///
/// - The transaction has a valid [TransactionId].
/// - [merchantId] is always present.
/// - A transaction without an external merchant uses the designated self
///   merchant identifier rather than a nullable merchant.
/// - At least one ledger entry exists.
/// - Ledger entries satisfy the structural rules associated with [kind].
/// - Expense transactions contain exactly one outgoing primary ledger entry.
/// - Income transactions contain exactly one incoming primary ledger entry.
/// - Balance corrections contain exactly one primary ledger entry.
/// - Transfers contain exactly two primary ledger entries, one incoming and one
///   outgoing.
/// - Splits are only permitted for transaction kinds that support allocation.
/// - When splits exist, every split's transaction and valuation amounts use the
///   same assets and directions as the corresponding primary ledger amounts.
/// - When splits exist, neither the applicable primary ledger amounts nor any
///   split amounts may be unknown.
/// - The complete split collection reconciles exactly with both applicable
///   primary ledger amounts.
/// - [description] and [note], when present, are not blank.
/// - [modifiedAt] cannot precede [createdAt], as enforced by [AuditedEntity].
/// - [entityVersion] is greater than zero, as enforced by [AuditedEntity].
///
/// ## State semantics
///
/// [state] describes the lifecycle state of the financial event, such as
/// whether it is planned or actual. State does not change the semantic
/// boundary between ledger entries and splits.
///
/// Ledger entries remain responsible for account and asset impact, while splits
/// remain responsible for allocation.
///
/// ## Merchant semantics
///
/// Merchant identity is intentionally non-nullable. Financial events without an
/// external merchant use the designated self merchant identifier. This avoids
/// giving `null` multiple possible domain meanings.
///
/// ## Recurrence
///
/// Recurrence is deliberately not represented by this aggregate.
///
/// Recurrence rules, transaction-series membership, and series exceptions
/// belong to the separate transaction-series model and are outside this
/// aggregate's responsibilities.
///
/// Invalid aggregate states are rejected during construction.
@MappableClass()
final class Transaction extends AuditedEntity with TransactionMappable {
  /// The financial meaning of this transaction.
  final TransactionKind kind;

  /// The merchant associated with this transaction.
  ///
  /// When there is no external merchant, this contains the designated self
  /// merchant identifier.
  final MerchantId merchantId;

  /// An optional short description of the transaction.
  ///
  /// When present, the value is trimmed and cannot be blank.
  final String? description;

  /// An optional free-form note associated with the transaction.
  ///
  /// When present, the value is trimmed and cannot be blank.
  final String? note;

  /// The lifecycle state of the transaction.
  final TransactionState state;

  /// Allocations of transaction value to domain allocation targets.
  ///
  /// Splits do not affect account balances. Account and asset impact is
  /// represented exclusively by [ledgerEntries].
  ///
  /// When non-empty, this collection must reconcile exactly with the
  /// applicable primary ledger transaction and valuation amounts.
  final List<TransactionSplit> splits;

  /// The account and asset impacts belonging to this transaction.
  ///
  /// Ledger entries are the source of account-impact information. Additional
  /// roles such as fees or taxes may coexist with the primary entry or entries
  /// required by the transaction kind.
  final List<LedgerEntry> ledgerEntries;

  /// Creates a transaction.
  ///
  /// The supplied [splits] and [ledgerEntries] are defensively copied and
  /// exposed as immutable collections.
  ///
  /// Aggregate validation is performed in three stages:
  ///
  /// 1. ledger-entry structure is validated against [kind];
  /// 2. split availability is validated against [kind];
  /// 3. the complete split collection is reconciled against the applicable
  ///    primary ledger transaction and valuation amounts.
  ///
  /// Throws an [ArgumentError] when any transaction invariant is violated.
  ///
  /// Inherited entity validation additionally rejects invalid entity versions
  /// and audit timestamps.
  @MappableConstructor()
  Transaction({
    required TransactionId super.id,
    required this.kind,
    required this.merchantId,
    String? description,
    String? note,
    required this.state,
    required List<TransactionSplit> splits,
    required List<LedgerEntry> ledgerEntries,
    required super.createdAt,
    required super.modifiedAt,
    required super.entityVersion,
  }) : description = normalizeOptionalText(description, 'description'),
       note = normalizeOptionalText(note, 'note'),
       splits = List.unmodifiable(splits),
       ledgerEntries = List.unmodifiable(ledgerEntries) {
    _validateLedgerEntries();
    _validateSplits();
    _validateSplitReconciliation();
  }

  /// Validates ledger-entry structure against the transaction kind.
  ///
  /// Individual ledger-entry invariants are owned by [LedgerEntry]. This method
  /// validates only rules requiring knowledge of the transaction as a whole.
  void _validateLedgerEntries() {
    if (ledgerEntries.isEmpty) {
      throw ArgumentError.value(
        ledgerEntries,
        'ledgerEntries',
        'A transaction must contain at least one ledger entry.',
      );
    }

    final primaryEntries = ledgerEntries
        .where((entry) => entry.role == LedgerEntryRole.primary)
        .toList(growable: false);

    switch (kind) {
      case TransactionKind.expense:
        _requireSinglePrimaryEntry(
          primaryEntries,
          direction: AssetAmountDirection.outgoing,
        );

      case TransactionKind.income:
        _requireSinglePrimaryEntry(
          primaryEntries,
          direction: AssetAmountDirection.incoming,
        );

      case TransactionKind.balanceCorrection:
        _requirePrimaryEntryCount(primaryEntries, 1);

      case TransactionKind.transfer:
        _requireOpposingPrimaryEntries(primaryEntries);
    }
  }

  /// Validates whether the transaction kind permits allocation splits.
  ///
  /// The validity of an individual [TransactionSplit] is owned by that value
  /// object. This method only validates whether splits are meaningful for the
  /// transaction as a whole.
  void _validateSplits() {
    if (splits.isEmpty) {
      return;
    }

    if (!kind.supportsSplits) {
      throw ArgumentError.value(
        splits,
        'splits',
        'Transaction kind $kind does not support allocation splits.',
      );
    }
  }

  /// Validates reconciliation of the complete split collection.
  ///
  /// Split reconciliation is an aggregate invariant because no individual
  /// [TransactionSplit] can know the amount allocated by the other splits or
  /// the total transaction value represented by the ledger.
  ///
  /// When splits exist:
  ///
  /// - the applicable primary ledger amounts must be known;
  /// - every split amount must be known;
  /// - every split amount must use the same asset and direction as its
  ///   corresponding primary ledger amount;
  /// - the transaction and valuation sums must each equal their corresponding
  ///   primary ledger amount exactly.
  ///
  /// Throws an [ArgumentError] when reconciliation fails.
  void _validateSplitReconciliation() {
    if (splits.isEmpty) {
      return;
    }

    // _validateLedgerEntries() and _validateSplits() run before this method.
    // A split-supporting transaction therefore has exactly one applicable
    // primary entry at this point.
    final primaryEntry = ledgerEntries.singleWhere(
      (entry) => entry.role == LedgerEntryRole.primary,
    );

    final transactionAmount = primaryEntry.transactionAmount;
    final valuationAmount = primaryEntry.valuationAmount;

    if (transactionAmount.isUnknownAmount || valuationAmount.isUnknownAmount) {
      throw ArgumentError.value(
        splits,
        'splits',
        'Splits cannot be reconciled when a primary ledger amount is unknown.',
      );
    }

    var allocatedTransactionAmount = Decimal.zero;
    var allocatedValuationAmount = Decimal.zero;

    for (final split in splits) {
      _validateSplitAmount(
        split: split,
        splitAmount: split.transactionAmount,
        primaryAmount: transactionAmount,
        representation: 'transaction',
      );
      _validateSplitAmount(
        split: split,
        splitAmount: split.valuationAmount,
        primaryAmount: valuationAmount,
        representation: 'valuation',
      );

      allocatedTransactionAmount += split.transactionAmount.amount;
      allocatedValuationAmount += split.valuationAmount.amount;
    }

    if (allocatedTransactionAmount != transactionAmount.amount) {
      throw ArgumentError.value(
        splits,
        'splits',
        'Transaction split amounts must reconcile exactly with the applicable '
            'primary ledger transaction amount.',
      );
    }

    if (allocatedValuationAmount != valuationAmount.amount) {
      throw ArgumentError.value(
        splits,
        'splits',
        'Transaction split amounts must reconcile exactly with the applicable '
            'primary ledger valuation amount.',
      );
    }
  }

  void _validateSplitAmount({
    required TransactionSplit split,
    required AssetAmount splitAmount,
    required AssetAmount primaryAmount,
    required String representation,
  }) {
    if (splitAmount.isUnknownAmount) {
      throw ArgumentError.value(
        split,
        'splits',
        'A transaction split cannot have an unknown $representation amount '
            'when reconciliation is required.',
      );
    }

    if (splitAmount.assetId != primaryAmount.assetId) {
      throw ArgumentError.value(
        split,
        'splits',
        'Every transaction split must use the same $representation asset as '
            'the applicable primary ledger amount.',
      );
    }

    if (splitAmount.direction != primaryAmount.direction) {
      throw ArgumentError.value(
        split,
        'splits',
        'Every transaction split must use the same $representation direction '
            'as the applicable primary ledger amount.',
      );
    }
  }

  /// Requires exactly one primary ledger entry with [direction].
  void _requireSinglePrimaryEntry(
    List<LedgerEntry> primaryEntries, {
    required AssetAmountDirection direction,
  }) {
    _requirePrimaryEntryCount(primaryEntries, 1);

    final primaryEntry = primaryEntries.single;

    if (primaryEntry.transactionAmount.direction != direction) {
      throw ArgumentError.value(
        ledgerEntries,
        'ledgerEntries',
        'Transaction kind $kind requires its primary ledger entry to be '
            '${direction.name}.',
      );
    }
  }

  /// Requires exactly [expectedCount] primary ledger entries.
  void _requirePrimaryEntryCount(
    List<LedgerEntry> primaryEntries,
    int expectedCount,
  ) {
    if (primaryEntries.length != expectedCount) {
      throw ArgumentError.value(
        ledgerEntries,
        'ledgerEntries',
        'Transaction kind $kind requires exactly $expectedCount primary '
            '${expectedCount == 1 ? 'ledger entry' : 'ledger entries'}.',
      );
    }
  }

  /// Requires exactly two primary entries with opposing directions.
  void _requireOpposingPrimaryEntries(List<LedgerEntry> primaryEntries) {
    _requirePrimaryEntryCount(primaryEntries, 2);

    final hasIncoming = primaryEntries.any(
      (entry) => entry.transactionAmount.isIncoming,
    );

    final hasOutgoing = primaryEntries.any(
      (entry) => entry.transactionAmount.isOutgoing,
    );

    if (!hasIncoming || !hasOutgoing) {
      throw ArgumentError.value(
        ledgerEntries,
        'ledgerEntries',
        'Transaction kind $kind requires one incoming and one outgoing '
            'primary ledger entry.',
      );
    }
  }
}
