import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/identity/ids/jar_id.dart';
import 'package:axiom/src/core/presentation/formatting/presentation_formatters.dart';
import 'package:axiom/src/core/presentation/tokens/design_tokens.dart';
import 'package:axiom/src/core/presentation/widgets/state/async_result_view.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/assets/presentation/formatting/asset_amount_formatter.dart';
import 'package:axiom/src/features/jars/presentation/state/jars_state.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Summary of transaction allocations affecting one jar.
final class JarAllocations extends ConsumerWidget {
  /// Creates a jar allocation summary.
  const JarAllocations({required this.jarId, super.key});

  final JarId jarId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(jarAllocationPresentationProvider(jarId));

    return AsyncResultView<JarAllocationPresentationData, BaseFailure>(
      value: value,
      onRetry: () {
        ref.invalidate(jarAllocationPresentationProvider(jarId));
      },
      loadingSemanticLabel: 'Loading jar allocations',
      builder: (context, data) {
        return _AllocationSummary(data: data);
      },
    );
  }
}

final class _AllocationSummary extends StatelessWidget {
  const _AllocationSummary({required this.data});

  final JarAllocationPresentationData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    var incoming = Decimal.zero;
    var outgoing = Decimal.zero;

    for (final entry in data.entries) {
      if (entry.amount.isIncoming) {
        incoming += entry.amount.amount;
      } else {
        outgoing += entry.amount.amount;
      }
    }

    final net = incoming - outgoing;

    return Card(
      elevation: 0,
      color: theme.colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.medium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Allocations',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Text(
                  '${data.entries.length}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.medium),
            _SummaryLine(
              label: 'Added',
              value: _format(
                context,
                AssetAmount.incoming(
                  assetId: data.valuationCurrency.id,
                  amount: incoming,
                ),
                data.valuationCurrency,
              ),
            ),
            const SizedBox(height: AppSpacing.xSmall),
            _SummaryLine(
              label: 'Removed',
              value: _format(
                context,
                AssetAmount.outgoing(
                  assetId: data.valuationCurrency.id,
                  amount: outgoing,
                ),
                data.valuationCurrency,
              ),
            ),
            const Divider(height: AppSpacing.large),
            _SummaryLine(
              label: 'Net',
              emphasized: true,
              value: _format(
                context,
                net < Decimal.zero
                    ? AssetAmount.outgoing(
                        assetId: data.valuationCurrency.id,
                        amount: net.abs(),
                      )
                    : AssetAmount.incoming(
                        assetId: data.valuationCurrency.id,
                        amount: net,
                      ),
                data.valuationCurrency,
                includeDirection: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final style = emphasized
        ? Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)
        : Theme.of(context).textTheme.bodyMedium;

    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        Text(value, style: style),
      ],
    );
  }
}

String _format(
  BuildContext context,
  AssetAmount amount,
  Currency currency, {
  bool includeDirection = false,
}) {
  return AssetAmountFormatter(
    numbers: PresentationFormatters.of(context).numbers,
  ).currency(amount, currency, includeDirectionSign: includeDirection);
}
