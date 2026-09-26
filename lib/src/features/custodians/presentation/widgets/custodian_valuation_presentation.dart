import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/identity/ids/custodian_id.dart';
import 'package:axiom/src/core/presentation/failures/presentation_failure_mapper.dart';
import 'package:axiom/src/core/presentation/formatting/presentation_formatters.dart';
import 'package:axiom/src/core/presentation/tokens/design_tokens.dart';
import 'package:axiom/src/core/presentation/widgets/state/async_result_view.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/custodians/presentation/state/custodians_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Custodian valuation presentation mode.
enum CustodianValuationPresentationMode { compact, detailed }

/// Displays a custodian's aggregate value.
///
/// No aggregation or conversion arithmetic is performed by this widget.
final class CustodianValuationPresentation extends ConsumerWidget {
  /// Creates custodian valuation presentation.
  const CustodianValuationPresentation({
    required this.custodianId,
    this.mode = CustodianValuationPresentationMode.compact,
    super.key,
  });

  final CustodianId custodianId;
  final CustodianValuationPresentationMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(custodianValuationProvider(custodianId));

    return switch (mode) {
      CustodianValuationPresentationMode.compact => _compact(context, value),
      CustodianValuationPresentationMode.detailed => _detailed(
        context,
        ref,
        value,
      ),
    };
  }

  Widget _compact(
    BuildContext context,
    AsyncValue<Result<CustodianValuationPresentationData, BaseFailure>> value,
  ) {
    final mapper = const PresentationFailureMapper();

    return value.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      loading: () => Semantics(
        label: 'Loading custodian value',
        child: SizedBox.square(
          dimension: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (error, stackTrace) {
        final failure = mapper.fromObject(error);

        return Tooltip(
          message: failure.message,
          child: Icon(
            Icons.error_outline_rounded,
            size: AppSize.iconSmall,
            color: Theme.of(context).colorScheme.error,
          ),
        );
      },
      data: (result) {
        return result.when(
          success: (data) {
            final formatted = _formatTotal(context, data);

            return Semantics(
              label:
                  '$formatted, '
                  '${data.aggregation.accountCount} accounts',
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      formatted,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _accountCountLabel(data.aggregation.accountCount),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          failure: (failure) {
            final presentation = mapper.fromFailure(failure);

            return Tooltip(
              message: presentation.message,
              child: Icon(
                Icons.error_outline_rounded,
                size: AppSize.iconSmall,
                color: Theme.of(context).colorScheme.error,
              ),
            );
          },
        );
      },
    );
  }

  Widget _detailed(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<Result<CustodianValuationPresentationData, BaseFailure>> value,
  ) {
    return AsyncResultView<CustodianValuationPresentationData, BaseFailure>(
      value: value,
      onRetry: () {
        ref.invalidate(custodianValuationProvider(custodianId));
      },
      loadingSemanticLabel: 'Loading custodian valuation',
      refreshSemanticLabel: 'Refreshing custodian valuation',
      builder: (context, data) {
        final theme = Theme.of(context);
        final formatted = _formatTotal(context, data);

        return Semantics(
          label:
              'Custodian value $formatted, '
              '${_accountCountLabel(data.aggregation.accountCount)}',
          child: ExcludeSemantics(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppRadius.large),
              ),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.medium),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total value',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxSmall),
                    Text(
                      formatted,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxSmall),
                    Text(
                      _accountCountLabel(data.aggregation.accountCount),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

String _formatTotal(
  BuildContext context,
  CustodianValuationPresentationData data,
) {
  final AssetAmount amount = data.aggregation.total;
  final signed = amount.isOutgoing ? -amount.amount : amount.amount;

  final formatted = PresentationFormatters.of(context).numbers.decimal(
    signed,
    maximumFractionDigits: data.valuationCurrency.decimalPlaces,
  );

  return '$formatted ${data.valuationCurrency.code.value}';
}

String _accountCountLabel(int count) {
  return count == 1 ? '1 account' : '$count accounts';
}
