import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/identity/ids/jar_id.dart';
import 'package:axiom/src/core/presentation/formatting/presentation_formatters.dart';
import 'package:axiom/src/core/presentation/tokens/design_tokens.dart';
import 'package:axiom/src/core/presentation/widgets/list/app_list_item.dart';
import 'package:axiom/src/core/presentation/widgets/state/async_result_view.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/assets/presentation/formatting/asset_amount_formatter.dart';
import 'package:axiom/src/features/jars/presentation/state/jars_state.dart';
import 'package:axiom/src/features/transactions/domain/enums/transaction_state.dart';
import 'package:axiom/src/features/transactions/presentation/formatting/transaction_display.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Transaction history allocated to one jar.
final class JarTransactionHistory extends ConsumerWidget {
  /// Creates a jar transaction history.
  const JarTransactionHistory({required this.jarId, super.key});

  final JarId jarId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(jarAllocationPresentationProvider(jarId));

    return AsyncResultView<JarAllocationPresentationData, BaseFailure>(
      value: value,
      isEmpty: (data) => data.entries.isEmpty,
      emptyTitle: 'No jar activity',
      emptyMessage: 'Transactions allocated to this jar will appear here.',
      onRetry: () {
        ref.invalidate(jarAllocationPresentationProvider(jarId));
      },
      loadingSemanticLabel: 'Loading jar transaction history',
      builder: (context, data) {
        return _History(data: data);
      },
    );
  }
}

final class _History extends StatelessWidget {
  const _History({required this.data});

  final JarAllocationPresentationData data;

  @override
  Widget build(BuildContext context) {
    final groups = <DateTime, List<JarAllocationEntry>>{};

    for (final entry in data.entries) {
      final local = entry.transaction.effectiveAt.toLocal();
      final day = DateTime(local.year, local.month, local.day);

      groups.putIfAbsent(day, () => <JarAllocationEntry>[]).add(entry);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final group in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.only(
              top: AppSpacing.small,
              bottom: AppSpacing.xxSmall,
            ),
            child: Text(
              PresentationFormatters.of(context).dates.date(group.key),
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
          for (var index = 0; index < group.value.length; index++) ...[
            _AllocationRow(
              entry: group.value[index],
              currency: data.valuationCurrency,
            ),
            if (index < group.value.length - 1)
              const Divider(height: 1, indent: 64),
          ],
        ],
      ],
    );
  }
}

final class _AllocationRow extends StatelessWidget {
  const _AllocationRow({required this.entry, required this.currency});

  final JarAllocationEntry entry;
  final Currency currency;

  @override
  Widget build(BuildContext context) {
    final transaction = entry.transaction;
    final amount = _formatAmount(context, entry.amount, currency);

    final subtitle = <String>[
      transactionKindLabel(transaction.kind),
      if (transaction.state == TransactionState.planned) 'Planned',
      if (transaction.note != null) 'Has note',
    ];

    return AppListItem(
      leading: Container(
        width: AppSize.entityVisual,
        height: AppSize.entityVisual,
        decoration: BoxDecoration(
          color: entry.amount.isIncoming
              ? Theme.of(context).colorScheme.tertiaryContainer
              : Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
        child: Icon(
          entry.amount.isIncoming
              ? Icons.arrow_downward_rounded
              : Icons.arrow_upward_rounded,
          color: entry.amount.isIncoming
              ? Theme.of(context).colorScheme.onTertiaryContainer
              : Theme.of(context).colorScheme.onErrorContainer,
        ),
      ),
      title: Text(
        transaction.description ?? transactionKindLabel(transaction.kind),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(subtitle.join(' · ')),
      trailing: Text(
        amount,
        textAlign: TextAlign.end,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      semanticLabel:
          '${transaction.description ?? transactionKindLabel(transaction.kind)}, '
          '$amount',
    );
  }
}

String _formatAmount(
  BuildContext context,
  AssetAmount amount,
  Currency currency,
) {
  return AssetAmountFormatter(
    numbers: PresentationFormatters.of(context).numbers,
  ).currency(amount, currency, includeDirectionSign: true);
}
