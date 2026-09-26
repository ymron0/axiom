import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/tag_id.dart';
import 'package:axiom/src/core/presentation/tokens/design_tokens.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_kind.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_state.dart';
import 'package:axiom/src/features/transactions/presentation/formatting/transaction_display.dart';
import 'package:axiom/src/features/transactions/presentation/state/transaction_activity_data.dart';
import 'package:axiom/src/features/transactions/presentation/state/transactions_view_state.dart';
import 'package:flutter/material.dart';

/// Result returned by the filtering/sorting sheet.
final class TransactionsFilterSelection {
  final TransactionFilters filters;
  final TransactionSortOrder sortOrder;

  /// Creates a selection.
  const TransactionsFilterSelection({
    required this.filters,
    required this.sortOrder,
  });
}

/// Filtering and sorting controls for transaction activity.
final class TransactionFilterSheet extends StatefulWidget {
  final TransactionFilters filters;
  final TransactionSortOrder sortOrder;
  final TransactionActivityData data;

  /// Creates the sheet.
  const TransactionFilterSheet({
    required this.filters,
    required this.sortOrder,
    required this.data,
    super.key,
  });

  @override
  State<TransactionFilterSheet> createState() => _TransactionFilterSheetState();
}

final class _TransactionFilterSheetState extends State<TransactionFilterSheet> {
  late Set<TransactionKind> _kinds;
  late Set<TransactionState> _states;
  late Set<AccountId> _accounts;
  late Set<TagId> _tags;
  late TransactionSortOrder _sortOrder;

  @override
  void initState() {
    super.initState();

    _kinds = {...widget.filters.kinds};
    _states = {...widget.filters.states};
    _accounts = {...widget.filters.accountIds};
    _tags = {...widget.filters.tagIds};
    _sortOrder = widget.sortOrder;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.medium,
          AppSpacing.xSmall,
          AppSpacing.medium,
          AppSpacing.large,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Filter & sort',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                TextButton(onPressed: _reset, child: const Text('Reset')),
              ],
            ),
            const SizedBox(height: AppSpacing.medium),
            DropdownButtonFormField<TransactionSortOrder>(
              key: ValueKey(_sortOrder),
              initialValue: _sortOrder,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Sort by'),
              items: [
                for (final value in TransactionSortOrder.values)
                  DropdownMenuItem(
                    value: value,
                    child: Text(_sortLabel(value)),
                  ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _sortOrder = value);
                }
              },
            ),
            const SizedBox(height: AppSpacing.small),
            ExpansionTile(
              title: const Text('Type'),
              subtitle: _kinds.isEmpty
                  ? null
                  : Text('${_kinds.length} selected'),
              children: [
                for (final kind in TransactionKind.values)
                  CheckboxListTile(
                    dense: true,
                    value: _kinds.contains(kind),
                    title: Text(transactionKindLabel(kind)),
                    onChanged: (selected) {
                      setState(() {
                        if (selected ?? false) {
                          _kinds.add(kind);
                        } else {
                          _kinds.remove(kind);
                        }
                      });
                    },
                  ),
              ],
            ),
            ExpansionTile(
              title: const Text('State'),
              subtitle: _states.isEmpty
                  ? null
                  : Text('${_states.length} selected'),
              children: [
                for (final state in TransactionState.values)
                  CheckboxListTile(
                    dense: true,
                    value: _states.contains(state),
                    title: Text(
                      state == TransactionState.actual ? 'Actual' : 'Planned',
                    ),
                    onChanged: (selected) {
                      setState(() {
                        if (selected ?? false) {
                          _states.add(state);
                        } else {
                          _states.remove(state);
                        }
                      });
                    },
                  ),
              ],
            ),
            ExpansionTile(
              title: const Text('Accounts'),
              subtitle: _accounts.isEmpty
                  ? null
                  : Text('${_accounts.length} selected'),
              children: [
                for (final account in widget.data.source.accounts)
                  CheckboxListTile(
                    dense: true,
                    value: _accounts.contains(account.id),
                    title: Text(
                      account.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onChanged: (selected) {
                      setState(() {
                        if (selected ?? false) {
                          _accounts.add(account.id);
                        } else {
                          _accounts.remove(account.id);
                        }
                      });
                    },
                  ),
              ],
            ),
            ExpansionTile(
              title: const Text('Tags'),
              subtitle: _tags.isEmpty ? null : Text('${_tags.length} selected'),
              children: [
                for (final tag in widget.data.source.tags)
                  CheckboxListTile(
                    dense: true,
                    value: _tags.contains(tag.id),
                    title: Text(
                      tag.archivedAt == null
                          ? tag.name
                          : '${tag.name} (archived)',
                    ),
                    onChanged: (selected) {
                      setState(() {
                        if (selected ?? false) {
                          _tags.add(tag.id);
                        } else {
                          _tags.remove(tag.id);
                        }
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.large),
            FilledButton(onPressed: _apply, child: const Text('Apply')),
          ],
        ),
      ),
    );
  }

  void _reset() {
    setState(() {
      _kinds.clear();
      _states.clear();
      _accounts.clear();
      _tags.clear();
      _sortOrder = TransactionSortOrder.newest;
    });
  }

  void _apply() {
    Navigator.of(context).pop(
      TransactionsFilterSelection(
        filters: TransactionFilters(
          kinds: _kinds,
          states: _states,
          accountIds: _accounts,
          tagIds: _tags,
        ),
        sortOrder: _sortOrder,
      ),
    );
  }

  String _sortLabel(TransactionSortOrder value) {
    return switch (value) {
      TransactionSortOrder.newest => 'Newest first',
      TransactionSortOrder.oldest => 'Oldest first',
      TransactionSortOrder.merchant => 'Merchant',
      TransactionSortOrder.valueDescending => 'Largest value first',
    };
  }
}
