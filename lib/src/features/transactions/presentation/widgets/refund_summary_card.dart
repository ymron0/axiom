import 'package:axiom/src/core/identity/ids/transaction_id.dart';
import 'package:decimal/decimal.dart';
import 'package:axiom/src/features/transactions/presentation/providers/refund_presentation_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/failures/base_failure.dart';
import '../../../../core/presentation/formatting/presentation_formatters.dart';
import '../../../../core/presentation/widgets/state/async_result_view.dart';
import '../models/refund_presentation_data.dart';

final class RefundSummaryCard extends ConsumerWidget {
  final TransactionId transactionId;
  final VoidCallback? onCreateRefund;

  const RefundSummaryCard({
    required this.transactionId,
    this.onCreateRefund,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final presentation = ref.watch(refundPresentationProvider(transactionId));

    return AsyncResultView<RefundPresentationData, BaseFailure>(
      value: presentation,
      onRetry: () {
        ref.invalidate(refundPresentationProvider(transactionId));
      },
      builder: (context, data) {
        final summary = data.summary;
        final asset = data.asset;
        final formatter = PresentationFormatters.of(context).numbers;

        String amount(dynamic value) {
          return formatter.currency(
            value,
            currencyCode: asset.code.value,
            decimalDigits: asset.decimalPlaces,
            symbol: asset.symbol,
          );
        }

        return Card(
          elevation: 0,
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Icon(Icons.receipt_long_outlined),
                    const SizedBox(width: 8),
                    Text(
                      'Refunds & offsets',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _AmountRow(
                  label: 'Original',
                  value: amount(summary.grossAmount),
                ),
                if (summary.refundAmount != Decimal.zero) // see note below
                  _AmountRow(
                    label: 'Refunded',
                    value: '−${amount(summary.refundAmount)}',
                  ),
                if (summary.reimbursementAmount != Decimal.zero)
                  _AmountRow(
                    label: 'Reimbursed',
                    value: '−${amount(summary.reimbursementAmount)}',
                  ),
                if (summary.cashbackAmount != Decimal.zero)
                  _AmountRow(
                    label: 'Cashback',
                    value: '−${amount(summary.cashbackAmount)}',
                  ),
                const Divider(height: 24),
                _AmountRow(
                  label: 'Net',
                  value: amount(summary.netAmount),
                  emphasized: true,
                ),
                if (data.offsets.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${data.offsets.length} linked '
                    '${data.offsets.length == 1 ? 'offset' : 'offsets'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                if (!summary.isFullyOffset && onCreateRefund != null) ...[
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: onCreateRefund,
                    icon: const Icon(Icons.undo_rounded),
                    label: const Text('Add refund'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

final class _AmountRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasized;

  const _AmountRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  @override
  Widget build(BuildContext context) {
    final style = emphasized
        ? Theme.of(context).textTheme.titleMedium
        : Theme.of(context).textTheme.bodyMedium;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}
