import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/merchant_id.dart';
import 'package:axiom/src/core/identity/ids/tag_id.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_kind.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_state.dart';

/// Criteria used to query transactions from a [TransactionRepository].
///
/// Criteria from different fields are combined using AND semantics.
///
/// Multiple values within the same field use OR semantics. For example:
///
/// ```dart
/// TransactionQuery(
///   kinds: {
///     TransactionKind.expense,
///     TransactionKind.income,
///   },
///   accountIds: {accountId},
/// )
/// ```
///
/// matches transactions that:
///
/// - are either an expense OR an income; AND
/// - affect [accountId].
///
/// Tag criteria follow the same rule. For example:
///
/// ```dart
/// TransactionQuery(
///   tagIds: {
///     businessTagId,
///     reimbursableTagId,
///   },
/// )
/// ```
///
/// matches a transaction when it references either tag.
///
/// When supplied, [effectiveFrom] is inclusive and [effectiveUntil] is
/// exclusive. Both bounds compare [Transaction.effectiveAt] as UTC instants.
///
/// An empty criterion means that property is unrestricted.
final class TransactionQuery {
  /// Transaction kinds to include.
  ///
  /// Empty means all transaction kinds.
  final Set<TransactionKind> kinds;

  /// Transaction states to include.
  ///
  /// Empty means all transaction states.
  final Set<TransactionState> states;

  /// Merchants to include.
  ///
  /// Empty means all merchants.
  final Set<MerchantId> merchantIds;

  /// Accounts that the transaction must affect.
  ///
  /// A transaction matches when at least one of its ledger entries references
  /// one of these accounts.
  ///
  /// Empty means transactions affecting any account.
  final Set<AccountId> accountIds;

  /// Tags that the transaction may reference.
  ///
  /// A transaction matches when at least one of its tag identities appears in
  /// this set.
  ///
  /// Multiple values use OR semantics. For example, a criterion containing
  /// `business` and `reimbursable` matches a transaction carrying either tag.
  ///
  /// Empty means the transaction's tag collection is unrestricted, including
  /// transactions with no tags.
  final Set<TagId> tagIds;

  /// Inclusive lower bound for [Transaction.effectiveAt].
  final DateTime? effectiveFrom;

  /// Exclusive upper bound for [Transaction.effectiveAt].
  final DateTime? effectiveUntil;

  /// Creates transaction query criteria.
  TransactionQuery({
    Set<TransactionKind> kinds = const {},
    Set<TransactionState> states = const {},
    Set<MerchantId> merchantIds = const {},
    Set<AccountId> accountIds = const {},
    Set<TagId> tagIds = const {},
    DateTime? effectiveFrom,
    DateTime? effectiveUntil,
  }) : kinds = Set.unmodifiable(kinds),
       states = Set.unmodifiable(states),
       merchantIds = Set.unmodifiable(merchantIds),
       accountIds = Set.unmodifiable(accountIds),
       tagIds = Set.unmodifiable(tagIds),
       effectiveFrom = effectiveFrom?.toUtc(),
       effectiveUntil = effectiveUntil?.toUtc() {
    if (this.effectiveFrom != null &&
        this.effectiveUntil != null &&
        this.effectiveUntil!.isBefore(this.effectiveFrom!)) {
      throw ArgumentError.value(
        effectiveUntil,
        'effectiveUntil',
        'Effective end time cannot precede effective start time.',
      );
    }
  }

  /// Whether this query contains no restrictions.
  bool get isEmpty =>
      kinds.isEmpty &&
      states.isEmpty &&
      merchantIds.isEmpty &&
      accountIds.isEmpty &&
      tagIds.isEmpty &&
      effectiveFrom == null &&
      effectiveUntil == null;
}