import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/presentation/failures/presentation_failure_mapper.dart';
import 'package:axiom/src/core/presentation/tokens/design_tokens.dart';
import 'package:axiom/src/core/presentation/widgets/content/app_content.dart';
import 'package:axiom/src/core/presentation/widgets/state/async_result_view.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_occurrence_deletion_mode.dart';
import 'package:axiom/src/features/transactions/presentation/mutations/transaction_mutations.dart';
import 'package:axiom/src/features/transactions/presentation/providers/transaction_month_source_provider.dart';
import 'package:axiom/src/features/transactions/presentation/providers/transactions_view_controller.dart';
import 'package:axiom/src/features/transactions/presentation/sheets/transaction_details_sheet.dart';
import 'package:axiom/src/features/transactions/presentation/sheets/transaction_editor_sheet.dart';
import 'package:axiom/src/features/transactions/presentation/sheets/transaction_filter_sheet.dart';
import 'package:axiom/src/features/transactions/presentation/sheets/transaction_refund_sheet.dart';
import 'package:axiom/src/features/transactions/presentation/state/transaction_activity_data.dart';
import 'package:axiom/src/features/transactions/presentation/widgets/transaction_list.dart';
import 'package:axiom/src/features/transactions/presentation/widgets/transaction_month_selector.dart';
import 'package:axiom/src/features/transactions/presentation/widgets/transaction_summary_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Primary transaction activity destination.
@RoutePage()
final class ActivityPage extends ConsumerStatefulWidget {
  /// Creates the Activity page.
  const ActivityPage({super.key});

  @override
  ConsumerState<ActivityPage> createState() => _ActivityPageState();
}

final class _ActivityPageState extends ConsumerState<ActivityPage> {
  late final TextEditingController _searchController;

  bool _searching = false;
  bool _upcomingExpanded = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewState = ref.watch(transactionsViewControllerProvider);
    final activity = ref.watch(transactionActivityDataProvider);
    final loadedData = activity.asData?.value.valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                textInputAction: TextInputAction.search,
                decoration: const InputDecoration(
                  hintText: 'Search transactions',
                  border: InputBorder.none,
                ),
                onChanged: ref
                    .read(transactionsViewControllerProvider.notifier)
                    .setSearchQuery,
              )
            : const Text('Activity'),
        actions: [
          IconButton(
            tooltip: _searching ? 'Close search' : 'Search transactions',
            onPressed: _toggleSearch,
            icon: Icon(_searching ? Icons.close_rounded : Icons.search_rounded),
          ),
          IconButton(
            tooltip: 'Filter and sort',
            onPressed: loadedData == null
                ? null
                : () => _openFilters(loadedData),
            icon: viewState.filters.isActive
                ? Badge(
                    label: Text('${viewState.filters.selectedCount}'),
                    child: const Icon(Icons.more_vert_rounded),
                  )
                : const Icon(Icons.more_vert_rounded),
          ),
        ],
      ),
      body: AsyncResultView<TransactionActivityData, BaseFailure>(
        value: activity,
        loadingSemanticLabel: 'Loading transactions',
        refreshSemanticLabel: 'Refreshing transactions',
        onRetry: _refresh,
        builder: (context, data) {
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                AppContent(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TransactionMonthSelector(
                        selectedMonth: viewState.monthStart,
                        currentYear: data.now.year,
                        onSelected: ref
                            .read(transactionsViewControllerProvider.notifier)
                            .selectMonth,
                      ),
                      const SizedBox(height: AppSpacing.small),
                      ActualProjectedSelector(
                        value: viewState.viewMode,
                        onChanged: ref
                            .read(transactionsViewControllerProvider.notifier)
                            .setViewMode,
                      ),
                      const SizedBox(height: AppSpacing.small),
                      TransactionSummaryView(summary: data.summary, data: data),
                      if (data.upcomingTransactions.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.medium),
                        UpcomingTransactionsSection(
                          transactions: data.upcomingTransactions,
                          data: data,
                          expanded: _upcomingExpanded,
                          onToggle: () {
                            setState(() {
                              _upcomingExpanded = !_upcomingExpanded;
                            });
                          },
                          onTransactionTap: (transaction) {
                            _openDetails(transaction, data);
                          },
                        ),
                      ],
                      const SizedBox(height: AppSpacing.medium),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Transactions',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          if (viewState.hasSearch || viewState.filters.isActive)
                            TextButton(
                              onPressed: _clearRefinements,
                              child: const Text('Clear'),
                            ),
                        ],
                      ),
                      if (data.transactions.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.xxLarge,
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.receipt_long_outlined,
                                size: 48,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                              const SizedBox(height: AppSpacing.small),
                              Text(
                                viewState.hasSearch ||
                                        viewState.filters.isActive
                                    ? 'No matching transactions'
                                    : 'No transactions this month',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: AppSpacing.xxSmall),
                              Text(
                                viewState.hasSearch ||
                                        viewState.filters.isActive
                                    ? 'Change the search or filters to see '
                                          'more results.'
                                    : 'Create a transaction to get started.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                    ),
                              ),
                            ],
                          ),
                        )
                      else
                        TransactionList(
                          transactions: data.transactions,
                          data: data,
                          onTransactionTap: (transaction) {
                            _openDetails(transaction, data);
                          },
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Create transaction',
        onPressed: loadedData == null ? null : () => _openEditor(loadedData),
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  void _toggleSearch() {
    setState(() {
      _searching = !_searching;

      if (!_searching) {
        _searchController.clear();

        ref
            .read(transactionsViewControllerProvider.notifier)
            .setSearchQuery('');
      }
    });
  }

  void _clearRefinements() {
    _searchController.clear();

    ref.read(transactionsViewControllerProvider.notifier).clearRefinements();

    if (_searching) {
      setState(() => _searching = false);
    }
  }

  Future<void> _openFilters(TransactionActivityData data) async {
    final state = ref.read(transactionsViewControllerProvider);

    final selection = await showModalBottomSheet<TransactionsFilterSelection>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return TransactionFilterSheet(
          filters: state.filters,
          sortOrder: state.sortOrder,
          data: data,
        );
      },
    );

    if (selection == null) {
      return;
    }

    final controller = ref.read(transactionsViewControllerProvider.notifier);

    controller
      ..setFilters(selection.filters)
      ..setSortOrder(selection.sortOrder);
  }

  Future<void> _openEditor(
    TransactionActivityData data, {
    Transaction? transaction,
  }) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.94,
          child: TransactionEditorSheet(data: data, transaction: transaction),
        );
      },
    );

    if (changed ?? false) {
      await _refresh();
    }
  }

  Future<void> _openDetails(
    Transaction transaction,
    TransactionActivityData data,
  ) async {
    final action = await showModalBottomSheet<TransactionDetailsAction>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.92,
          child: TransactionDetailsSheet(transaction: transaction, data: data),
        );
      },
    );

    if (!mounted || action == null) {
      return;
    }

    switch (action) {
      case TransactionDetailsAction.edit:
        await _openEditor(data, transaction: transaction);

      case TransactionDetailsAction.refund:
        await _openRefund(transaction, data);

      case TransactionDetailsAction.delete:
        await _deleteTransaction(transaction);
    }
  }

  Future<void> _openRefund(
    Transaction transaction,
    TransactionActivityData data,
  ) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.88,
          child: TransactionRefundSheet(transaction: transaction, data: data),
        );
      },
    );

    if (changed ?? false) {
      await _refresh();
    }
  }

  Future<void> _deleteTransaction(Transaction transaction) async {
    if (transaction.recurrenceOrigin != null) {
      await _deleteOccurrence(transaction);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete transaction?'),
          content: const Text(
            'The transaction will be removed. You can undo the deletion '
            'immediately afterwards.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (!(confirmed ?? false) || !mounted) {
      return;
    }

    try {
      final snapshot = await runDeleteTransactionMutation(ref, transaction);

      await _refresh();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Transaction deleted'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              unawaited(_restoreTransaction(snapshot));
            },
          ),
        ),
      );
    } catch (error) {
      _showMutationError(error);
    }
  }

  Future<void> _deleteOccurrence(Transaction transaction) async {
    final mode = await showDialog<TransactionOccurrenceDeletionMode>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text('Delete recurring occurrence'),
          children: [
            SimpleDialogOption(
              onPressed: () {
                Navigator.of(
                  context,
                ).pop(TransactionOccurrenceDeletionMode.skip);
              },
              child: const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.delete_outline_rounded),
                title: Text('Delete without replacement'),
                subtitle: Text('Skip this recurrence slot permanently.'),
              ),
            ),
            SimpleDialogOption(
              onPressed: () {
                Navigator.of(
                  context,
                ).pop(TransactionOccurrenceDeletionMode.regenerate);
              },
              child: const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.refresh_rounded),
                title: Text('Replace immediately'),
                subtitle: Text('Regenerate this recurrence slot.'),
              ),
            ),
            SimpleDialogOption(
              onPressed: () {
                Navigator.of(
                  context,
                ).pop(TransactionOccurrenceDeletionMode.skipAndAppend);
              },
              child: const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.redo_rounded),
                title: Text('Skip and add at end'),
                subtitle: Text('Skip this slot and extend a finite series.'),
              ),
            ),
          ],
        );
      },
    );

    if (mode == null || !mounted) {
      return;
    }

    try {
      await runDeleteTransactionOccurrenceMutation(
        ref,
        transaction: transaction,
        mode: mode,
      );

      await _refresh();
    } catch (error) {
      _showMutationError(error);
    }
  }

  Future<void> _restoreTransaction(Transaction snapshot) async {
    try {
      await runRestoreTransactionMutation(ref, snapshot);
      await _refresh();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Transaction restored')));
      }
    } catch (error) {
      _showMutationError(error);
    }
  }

  Future<void> _refresh() async {
    final state = ref.read(transactionsViewControllerProvider);

    ref.invalidate(transactionMonthSourceProvider(state.monthStart));

    try {
      await ref.read(transactionMonthSourceProvider(state.monthStart).future);
    } catch (_) {
      // AsyncResultView owns unexpected asynchronous error presentation.
    }
  }

  void _showMutationError(Object error) {
    if (!mounted) {
      return;
    }

    final mapper = const PresentationFailureMapper();

    final failure = error is TransactionMutationFailure
        ? mapper.fromFailure(error.failure)
        : mapper.fromObject(error);

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(failure.message)));
  }
}
