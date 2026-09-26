import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/tag_id.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_kind.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_state.dart';
import 'package:flutter/foundation.dart';

/// Determines which lifecycle values contribute to the primary transaction view.
enum TransactionViewMode {
  /// Displays only recorded financial activity.
  actual,

  /// Displays actual activity plus planned activity.
  projected,
}

/// Ordering applied after transaction search and filtering.
enum TransactionSortOrder {
  /// Most recent transaction first.
  newest,

  /// Oldest transaction first.
  oldest,

  /// Counterparty alphabetically.
  merchant,

  /// Largest valuation-currency magnitude first.
  valueDescending,
}

/// Explicit transaction filters selected by the user.
///
/// Empty sets mean unrestricted values.
@immutable
final class TransactionFilters {
  final Set<TransactionKind> kinds;
  final Set<TransactionState> states;
  final Set<AccountId> accountIds;
  final Set<TagId> tagIds;

  /// Creates immutable transaction filters.
  TransactionFilters({
    Set<TransactionKind> kinds = const {},
    Set<TransactionState> states = const {},
    Set<AccountId> accountIds = const {},
    Set<TagId> tagIds = const {},
  }) : kinds = Set.unmodifiable(kinds),
       states = Set.unmodifiable(states),
       accountIds = Set.unmodifiable(accountIds),
       tagIds = Set.unmodifiable(tagIds);

  /// No explicit transaction filters.
  factory TransactionFilters.empty() {
    return TransactionFilters();
  }

  /// Whether at least one explicit criterion is active.
  bool get isActive =>
      kinds.isNotEmpty ||
      states.isNotEmpty ||
      accountIds.isNotEmpty ||
      tagIds.isNotEmpty;

  /// Number of selected individual criteria.
  int get selectedCount =>
      kinds.length + states.length + accountIds.length + tagIds.length;

  /// Creates a changed copy.
  TransactionFilters copyWith({
    Set<TransactionKind>? kinds,
    Set<TransactionState>? states,
    Set<AccountId>? accountIds,
    Set<TagId>? tagIds,
  }) {
    return TransactionFilters(
      kinds: kinds ?? this.kinds,
      states: states ?? this.states,
      accountIds: accountIds ?? this.accountIds,
      tagIds: tagIds ?? this.tagIds,
    );
  }
}

/// User-controlled state for the Activity destination.
///
/// Repository data is deliberately not stored here. It remains owned by
/// asynchronous read providers.
@immutable
final class TransactionsViewState {
  /// First local-calendar day of the selected month.
  final DateTime monthStart;

  /// Actual or projected presentation.
  final TransactionViewMode viewMode;

  /// Free-text search query.
  final String searchQuery;

  /// Explicit filtering criteria.
  final TransactionFilters filters;

  /// Selected ordering.
  final TransactionSortOrder sortOrder;

  /// Creates immutable transaction presentation state.
  TransactionsViewState({
    required DateTime monthStart,
    required this.viewMode,
    required this.searchQuery,
    required this.filters,
    required this.sortOrder,
  }) : monthStart = DateTime(monthStart.year, monthStart.month);

  /// Creates initial state for [now].
  factory TransactionsViewState.initial(DateTime now) {
    return TransactionsViewState(
      monthStart: DateTime(now.year, now.month),
      viewMode: TransactionViewMode.actual,
      searchQuery: '',
      filters: TransactionFilters.empty(),
      sortOrder: TransactionSortOrder.newest,
    );
  }

  /// Whether text search is active.
  bool get hasSearch => searchQuery.trim().isNotEmpty;

  /// Creates a changed copy.
  TransactionsViewState copyWith({
    DateTime? monthStart,
    TransactionViewMode? viewMode,
    String? searchQuery,
    TransactionFilters? filters,
    TransactionSortOrder? sortOrder,
  }) {
    return TransactionsViewState(
      monthStart: monthStart ?? this.monthStart,
      viewMode: viewMode ?? this.viewMode,
      searchQuery: searchQuery ?? this.searchQuery,
      filters: filters ?? this.filters,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}
