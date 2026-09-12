import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/merchant_id.dart';
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
/// An empty criterion means that property is unrestricted.
final class TransactionQuery {
  /// Creates transaction query criteria.
  TransactionQuery({
    Set<TransactionKind> kinds = const {},
    Set<TransactionState> states = const {},
    Set<MerchantId> merchantIds = const {},
    Set<AccountId> accountIds = const {},
  }) : kinds = Set.unmodifiable(kinds),
       states = Set.unmodifiable(states),
       merchantIds = Set.unmodifiable(merchantIds),
       accountIds = Set.unmodifiable(accountIds);

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

  /// Whether this query contains no restrictions.
  bool get isEmpty =>
      kinds.isEmpty &&
      states.isEmpty &&
      merchantIds.isEmpty &&
      accountIds.isEmpty;
}
