import 'package:axiom/src/core/presentation/formatting/presentation_formatters.dart';
import 'package:axiom/src/core/presentation/tokens/design_tokens.dart';
import 'package:axiom/src/core/presentation/widgets/list/app_list_item.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:axiom/src/features/transactions/domain/enums/ledger_entry_role.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_kind.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_state.dart';
import 'package:axiom/src/features/transactions/presentation/formatting/transaction_display.dart';
import 'package:axiom/src/features/transactions/presentation/state/transaction_activity_data.dart';
import 'package:axiom/src/features/transactions/presentation/state/transactions_view_state.dart';
import 'package:flutter/material.dart';

/// Two simple text actions controlling actual/projected mode.
final class ActualProjectedSelector extends StatelessWidget {
  final TransactionViewMode value;
  final ValueChanged<TransactionViewMode> onChanged;

  /// Creates an actual/projected selector.
  const ActualProjectedSelector({
    required this.value,
    required this.onChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ViewButton(
          label: 'Actual',
          selected: value == TransactionViewMode.actual,
          onTap: () => onChanged(TransactionViewMode.actual),
        ),
        const SizedBox(width: AppSpacing.xSmall),
        _ViewButton(
          label: 'Projected',
          selected: value == TransactionViewMode.projected,
          onTap: () => onChanged(TransactionViewMode.projected),
        ),
      ],
    );
  }
}

final class _ViewButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ViewButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: TextButton(
        onPressed: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label),
            const SizedBox(height: 2),
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: selected ? 28 : 0,
              height: 2,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Flat transaction list grouped by calendar day.
final class TransactionList extends StatelessWidget {
  final List<Transaction> transactions;
  final TransactionActivityData data;
  final ValueChanged<Transaction> onTransactionTap;
  final bool showGroupTotals;

  /// Creates the grouped list.
  const TransactionList({
    required this.transactions,
    required this.data,
    required this.onTransactionTap,
    this.showGroupTotals = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final groups = <DateTime, List<Transaction>>{};

    for (final transaction in transactions) {
      final local = transaction.effectiveAt.toLocal();
      final day = DateTime(local.year, local.month, local.day);

      groups.putIfAbsent(day, () => <Transaction>[]).add(transaction);
    }

    return Column(
      children: [
        for (final entry in groups.entries) ...[
          _DayHeader(
            day: entry.key,
            transactions: entry.value,
            data: data,
            showTotal: showGroupTotals,
          ),
          for (var index = 0; index < entry.value.length; index++) ...[
            TransactionRow(
              transaction: entry.value[index],
              data: data,
              onTap: () => onTransactionTap(entry.value[index]),
            ),
            if (index < entry.value.length - 1)
              const Divider(height: 1, indent: 64),
          ],
          const SizedBox(height: AppSpacing.small),
        ],
      ],
    );
  }
}

final class _DayHeader extends StatelessWidget {
  final DateTime day;
  final List<Transaction> transactions;
  final TransactionActivityData data;
  final bool showTotal;

  const _DayHeader({
    required this.day,
    required this.transactions,
    required this.data,
    required this.showTotal,
  });

  @override
  Widget build(BuildContext context) {
    final summary = TransactionSummary.calculate(
      transactions: transactions,
      valuationAssetId: data.source.valuationCurrency.id,
    );

    final numbers = PresentationFormatters.of(context).numbers;
    final currency = data.source.valuationCurrency;

    final total = numbers.currency(
      summary.net,
      currencyCode: currency.code.value,
      symbol: currency.symbol,
      decimalDigits: currency.decimalPlaces,
    );

    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.xSmall,
        bottom: AppSpacing.xxSmall,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              PresentationFormatters.of(context).dates.date(day),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          if (showTotal && summary.includedTransactionCount > 0)
            Text(
              total,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

/// Compact individual transaction row.
final class TransactionRow extends StatelessWidget {
  final Transaction transaction;
  final TransactionActivityData data;
  final VoidCallback onTap;

  /// Creates a transaction row.
  const TransactionRow({
    required this.transaction,
    required this.data,
    required this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final primaryEntries = transaction.ledgerEntries
        .where((entry) => entry.role == LedgerEntryRole.primary)
        .toList(growable: false);

    final counterparty = transactionCounterparty(transaction, data);

    final financialLine = _financialLine(context, primaryEntries);

    final subtitleLines = <String>[
      if (transaction.description != null) transaction.description!,
      ?financialLine,
      if (transaction.state == TransactionState.planned) 'Planned',
    ];

    final trailing = primaryEntries.length == 1
        ? Text(
            formatTransactionAssetAmount(
              context,
              primaryEntries.single.transactionAmount,
              data,
            ),
            textAlign: TextAlign.end,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          )
        : const Icon(Icons.chevron_right_rounded);

    return AppListItem(
      leading: _TransactionIcon(transaction: transaction),
      title: Row(
        children: [
          Expanded(child: Text(counterparty, overflow: TextOverflow.ellipsis)),
          if (transaction.note != null) ...[
            const SizedBox(width: AppSpacing.xxSmall),
            Icon(
              Icons.notes_rounded,
              size: AppSize.iconSmall,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ],
      ),
      subtitle: subtitleLines.isEmpty
          ? null
          : Text(
              subtitleLines.join('\n'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 116),
        child: trailing,
      ),
      semanticLabel:
          '$counterparty, ${transactionKindLabel(transaction.kind)}, '
          '${financialLine ?? ''}',
      onTap: onTap,
    );
  }

  String? _financialLine(BuildContext context, List primaryEntries) {
    if (primaryEntries.isEmpty) {
      return null;
    }

    if (primaryEntries.length > 1) {
      final outgoing = primaryEntries.where(
        (entry) => entry.transactionAmount.isOutgoing,
      );

      final incoming = primaryEntries.where(
        (entry) => entry.transactionAmount.isIncoming,
      );

      if (outgoing.isNotEmpty && incoming.isNotEmpty) {
        return '${formatTransactionAssetAmount(context, outgoing.first.transactionAmount, data)}  →  ${formatTransactionAssetAmount(context, incoming.first.transactionAmount, data)}';
      }

      return null;
    }

    final entry = primaryEntries.single;

    if (entry.transactionAmount.assetId == entry.valuationAmount.assetId) {
      return null;
    }

    return '≈ ${formatTransactionAssetAmount(context, entry.valuationAmount, data)}';
  }
}

final class _TransactionIcon extends StatelessWidget {
  final Transaction transaction;

  const _TransactionIcon({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final (background, foreground) = switch (transaction.kind) {
      TransactionKind.expense => (
        scheme.errorContainer,
        scheme.onErrorContainer,
      ),
      TransactionKind.income ||
      TransactionKind.dividend ||
      TransactionKind.reward => (
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
      ),
      TransactionKind.transfer => (
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
      ),
      TransactionKind.buy || TransactionKind.sell => (
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
      ),
      TransactionKind.balanceCorrection => (
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
      ),
    };

    return Container(
      width: AppSize.entityVisual,
      height: AppSize.entityVisual,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      child: Icon(
        transaction.state == TransactionState.planned
            ? Icons.schedule_rounded
            : transactionKindIcon(transaction.kind),
        color: foreground,
        size: AppSize.iconMedium,
      ),
    );
  }
}

/// Collapsible future planned-transaction section.
final class UpcomingTransactionsSection extends StatelessWidget {
  final List<Transaction> transactions;
  final TransactionActivityData data;
  final bool expanded;
  final VoidCallback onToggle;
  final ValueChanged<Transaction> onTransactionTap;

  /// Creates the upcoming section.
  const UpcomingTransactionsSection({
    required this.transactions,
    required this.data,
    required this.expanded,
    required this.onToggle,
    required this.onTransactionTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        Semantics(
          button: true,
          expanded: expanded,
          label: 'Upcoming transactions, ${transactions.length}',
          child: InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(AppRadius.medium),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: AppSize.interactive),
              child: Row(
                children: [
                  const Icon(Icons.schedule_rounded),
                  const SizedBox(width: AppSpacing.xSmall),
                  Expanded(
                    child: Text(
                      'Upcoming',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Text(
                    '${transactions.length}',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(width: AppSpacing.xxSmall),
                  Icon(
                    expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (expanded)
          TransactionList(
            transactions: transactions,
            data: data,
            showGroupTotals: false,
            onTransactionTap: onTransactionTap,
          ),
      ],
    );
  }
}
