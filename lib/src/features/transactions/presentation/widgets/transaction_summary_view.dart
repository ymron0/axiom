import 'package:axiom/src/core/presentation/formatting/presentation_formatters.dart';
import 'package:axiom/src/core/presentation/tokens/design_tokens.dart';
import 'package:axiom/src/features/transactions/presentation/state/transaction_activity_data.dart';
import 'package:flutter/material.dart';

/// Compact monthly income/expense/net summary.
final class TransactionSummaryView extends StatelessWidget {
  final TransactionSummary summary;
  final TransactionActivityData data;

  /// Creates a summary view.
  const TransactionSummaryView({
    required this.summary,
    required this.data,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final numbers = PresentationFormatters.of(context).numbers;
    final currency = data.source.valuationCurrency;

    String format(value) {
      return numbers.currency(
        value,
        currencyCode: currency.code.value,
        symbol: currency.symbol,
        decimalDigits: currency.decimalPlaces,
      );
    }

    return Semantics(
      container: true,
      label: 'Transaction summary',
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.medium),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.large),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _SummaryValue(
                    label: 'Income',
                    value: format(summary.income),
                  ),
                ),
                Expanded(
                  child: _SummaryValue(
                    label: 'Expenses',
                    value: format(summary.expense),
                  ),
                ),
                Expanded(
                  child: _SummaryValue(
                    label: 'Net',
                    value: format(summary.net),
                    emphasized: true,
                  ),
                ),
              ],
            ),
            if (summary.hasIncompleteValues) ...[
              const SizedBox(height: AppSpacing.xSmall),
              Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: AppSize.iconSmall,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpacing.xxSmall),
                  Expanded(
                    child: Text(
                      'Some values could not be included in the summary.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

final class _SummaryValue extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasized;

  const _SummaryValue({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.xxSmall),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style:
              (emphasized
                      ? Theme.of(context).textTheme.titleMedium
                      : Theme.of(context).textTheme.bodyLarge)
                  ?.copyWith(
                    fontWeight: emphasized ? FontWeight.w700 : FontWeight.w600,
                  ),
        ),
      ],
    );
  }
}
