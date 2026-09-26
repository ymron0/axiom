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

/// Displays current balance and target progress for a jar.
final class JarProgressView extends ConsumerWidget {
  /// Creates a jar progress view.
  const JarProgressView({required this.jarId, this.compact = false, super.key});

  final JarId jarId;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(jarProgressPresentationProvider(jarId));

    return AsyncResultView<JarProgressPresentationData, BaseFailure>(
      value: value,
      onRetry: () {
        ref.invalidate(jarProgressPresentationProvider(jarId));
      },
      loadingSemanticLabel: 'Loading jar progress',
      refreshSemanticLabel: 'Refreshing jar progress',
      builder: (context, data) {
        if (compact) {
          return _CompactProgress(data: data);
        }

        return _FullProgress(data: data);
      },
    );
  }
}

final class _CompactProgress extends StatelessWidget {
  const _CompactProgress({required this.data});

  final JarProgressPresentationData data;

  @override
  Widget build(BuildContext context) {
    final progress = data.progress;

    if (progress.progressRatio == null) {
      return Text(
        _formatAmount(context, progress.balance, data.valuationCurrency),
        textAlign: TextAlign.end,
        style: Theme.of(context).textTheme.labelLarge,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          PresentationFormatters.of(
            context,
          ).numbers.percentage(progress.progressRatio!),
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
        Text(
          _formatAmount(context, progress.savedAmount, data.valuationCurrency),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

final class _FullProgress extends StatelessWidget {
  const _FullProgress({required this.data});

  final JarProgressPresentationData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = data.progress;
    final ratio = progress.progressRatio;

    return Semantics(
      container: true,
      label: 'Jar progress',
      child: Card(
        elevation: 0,
        color: theme.colorScheme.surfaceContainerLow,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.medium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Progress', style: theme.textTheme.titleMedium),
              const SizedBox(height: AppSpacing.medium),
              _AmountLine(
                label: 'Balance',
                value: _formatAmount(
                  context,
                  progress.balance,
                  data.valuationCurrency,
                  includeDirection: true,
                ),
              ),
              if (progress.target != null) ...[
                const SizedBox(height: AppSpacing.small),
                _AmountLine(
                  label: 'Target',
                  value: _formatAmount(
                    context,
                    progress.target!.amount,
                    data.valuationCurrency,
                  ),
                ),
                const SizedBox(height: AppSpacing.small),
                _AmountLine(
                  label: 'Remaining',
                  value: _formatAmount(
                    context,
                    progress.remainingAmount!,
                    data.valuationCurrency,
                  ),
                ),
                const SizedBox(height: AppSpacing.medium),
                Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        value: double.parse(ratio!.toString()),
                        color: _progressColor(context, data),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.small),
                    Text(
                      PresentationFormatters.of(
                        context,
                      ).numbers.percentage(ratio),
                      style: theme.textTheme.labelLarge,
                    ),
                  ],
                ),
                if (progress.target!.targetDate != null) ...[
                  const SizedBox(height: AppSpacing.small),
                  Text(
                    'Target date: '
                    '${PresentationFormatters.of(context).dates.date(progress.target!.targetDate!.toDateTimeUtc())}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ] else ...[
                const SizedBox(height: AppSpacing.small),
                Text(
                  'No target is currently configured.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _progressColor(BuildContext context, JarProgressPresentationData data) {
    final scheme = Theme.of(context).colorScheme;
    final progress = data.progress;

    if (progress.isTargetReached) {
      return scheme.primary;
    }

    if (progress.progressRatio! >= Decimal.parse('0.8')) {
      return scheme.tertiary;
    }

    return scheme.onSurfaceVariant;
  }
}

final class _AmountLine extends StatelessWidget {
  const _AmountLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

String _formatAmount(
  BuildContext context,
  AssetAmount amount,
  Currency currency, {
  bool includeDirection = false,
}) {
  final formatter = AssetAmountFormatter(
    numbers: PresentationFormatters.of(context).numbers,
  );

  return formatter.currency(
    amount,
    currency,
    includeDirectionSign: includeDirection,
  );
}
