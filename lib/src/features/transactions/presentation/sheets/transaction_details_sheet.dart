import 'package:axiom/src/core/presentation/formatting/presentation_formatters.dart';
import 'package:axiom/src/core/presentation/tokens/design_tokens.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/enums/ledger_entry_role.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_kind.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_state.dart';
import 'package:axiom/src/features/transactions/presentation/formatting/transaction_display.dart';
import 'package:axiom/src/features/transactions/presentation/state/transaction_activity_data.dart';
import 'package:flutter/material.dart';

/// Action selected from transaction details.
enum TransactionDetailsAction { edit, refund, delete }

/// Detailed transaction presentation.
final class TransactionDetailsSheet extends StatelessWidget {
  final Transaction transaction;
  final TransactionActivityData data;

  /// Creates transaction details.
  const TransactionDetailsSheet({
    required this.transaction,
    required this.data,
    super.key,
  });

  bool get _canOffset =>
      transaction.state == TransactionState.actual &&
      !transaction.isOffset &&
      (transaction.kind == TransactionKind.expense ||
          transaction.kind == TransactionKind.income);

  @override
  Widget build(BuildContext context) {
    final dates = PresentationFormatters.of(context).dates;

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
            Text(
              transactionCounterparty(transaction, data),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.xxSmall),
            Text(
              '${transactionKindLabel(transaction.kind)} · '
              '${transaction.state == TransactionState.actual ? 'Actual' : 'Planned'}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xxSmall),
            Text(
              dates.dateTime(transaction.effectiveAt.toLocal()),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.large),
            _sectionTitle(context, 'Financial entries'),
            for (final entry in transaction.ledgerEntries)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  entry.role == LedgerEntryRole.fee
                      ? Icons.percent_rounded
                      : Icons.account_balance_wallet_outlined,
                ),
                title: Text(
                  data.source.accountsById[entry.accountId]?.name ??
                      'Unknown account',
                ),
                subtitle: Text(
                  [
                    formatTransactionAssetAmount(
                      context,
                      entry.transactionAmount,
                      data,
                    ),
                    if (entry.accountAmount.assetId !=
                        entry.transactionAmount.assetId)
                      'Account: ${formatTransactionAssetAmount(context, entry.accountAmount, data)}',
                    if (entry.valuationAmount.assetId !=
                        entry.transactionAmount.assetId)
                      'Value: ${formatTransactionAssetAmount(context, entry.valuationAmount, data)}',
                    if (entry.feePercentage != null)
                      'Fee expression: ${entry.feePercentage}%',
                  ].join('\n'),
                ),
              ),
            if (transaction.splits.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.medium),
              _sectionTitle(context, 'Allocations'),
              for (final split in transaction.splits)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.category_outlined),
                  title: Text(
                    [
                      if (split.categoryId != null)
                        data.source.categoriesById[split.categoryId]?.name ??
                            'Unknown category',
                      if (split.jarId != null)
                        data.source.jarsById[split.jarId]?.name ??
                            'Unknown jar',
                    ].join(' · '),
                  ),
                  subtitle: Text(
                    formatTransactionAssetAmount(
                      context,
                      split.transactionAmount,
                      data,
                    ),
                  ),
                ),
            ],
            if (transaction.tagIds.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.medium),
              _sectionTitle(context, 'Tags'),
              Wrap(
                spacing: AppSpacing.xSmall,
                runSpacing: AppSpacing.xSmall,
                children: [
                  for (final id in transaction.tagIds)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xSmall,
                        vertical: AppSpacing.xxSmall,
                      ),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(AppRadius.small),
                      ),
                      child: Text(
                        data.source.tagsById[id]?.name ?? 'Unknown tag',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                ],
              ),
            ],
            if (transaction.description != null ||
                transaction.note != null) ...[
              const SizedBox(height: AppSpacing.large),
              _sectionTitle(context, 'Details'),
              if (transaction.description != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.short_text_rounded),
                  title: const Text('Description'),
                  subtitle: Text(transaction.description!),
                ),
              if (transaction.note != null)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.notes_rounded),
                  title: const Text('Note'),
                  subtitle: Text(transaction.note!),
                ),
            ],
            if (transaction.isOffset) ...[
              const SizedBox(height: AppSpacing.medium),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.undo_rounded),
                title: const Text('Offset transaction'),
                subtitle: Text(
                  '${transaction.offset!.kind.name} · '
                  '${transaction.offset!.originalTransactionId.value}',
                ),
              ),
            ],
            if (transaction.recurrenceOrigin != null) ...[
              const SizedBox(height: AppSpacing.medium),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.repeat_rounded),
                title: const Text('Recurring occurrence'),
                subtitle: Text(
                  'Series ${transaction.recurrenceOrigin!.seriesId.value}',
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.large),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop(TransactionDetailsAction.edit);
                    },
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit'),
                  ),
                ),
                if (_canOffset) ...[
                  const SizedBox(width: AppSpacing.xSmall),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(
                          context,
                        ).pop(TransactionDetailsAction.refund);
                      },
                      icon: const Icon(Icons.undo_rounded),
                      label: const Text('Refund'),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppSpacing.xSmall),
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () {
                Navigator.of(context).pop(TransactionDetailsAction.delete);
              },
              icon: const Icon(Icons.delete_outline_rounded),
              label: const Text('Delete transaction'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) {
    return Text(text, style: Theme.of(context).textTheme.titleMedium);
  }
}
