import 'package:axiom/src/core/di/clock_provider.dart';
import 'package:axiom/src/features/transactions/presentation/state/transactions_view_state.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'transactions_view_controller.g.dart';

/// Owns user-controlled transaction browsing state.
///
/// Read data remains in separate asynchronous providers so local interactions
/// such as search or sorting do not cause unnecessary repository queries.
@riverpod
class TransactionsViewController extends _$TransactionsViewController {
  @override
  TransactionsViewState build() {
    return TransactionsViewState.initial(ref.watch(clockProvider).now);
  }

  /// Selects [month].
  void selectMonth(DateTime month) {
    state = state.copyWith(monthStart: DateTime(month.year, month.month));
  }

  /// Selects the previous month.
  void previousMonth() {
    final current = state.monthStart;
    selectMonth(DateTime(current.year, current.month - 1));
  }

  /// Selects the next month.
  void nextMonth() {
    final current = state.monthStart;
    selectMonth(DateTime(current.year, current.month + 1));
  }

  /// Returns to the current calendar month.
  void currentMonth() {
    final now = ref.read(clockProvider).now;
    selectMonth(DateTime(now.year, now.month));
  }

  /// Changes the actual/projected view.
  void setViewMode(TransactionViewMode value) {
    state = state.copyWith(viewMode: value);
  }

  /// Changes free-text search without querying persistence again.
  void setSearchQuery(String value) {
    state = state.copyWith(searchQuery: value);
  }

  /// Replaces explicit filters.
  void setFilters(TransactionFilters value) {
    state = state.copyWith(filters: value);
  }

  /// Replaces transaction ordering.
  void setSortOrder(TransactionSortOrder value) {
    state = state.copyWith(sortOrder: value);
  }

  /// Clears search and explicit filters while retaining month/view/sort state.
  void clearRefinements() {
    state = state.copyWith(
      searchQuery: '',
      filters: TransactionFilters.empty(),
    );
  }
}
