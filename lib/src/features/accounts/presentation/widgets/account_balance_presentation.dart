import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/presentation/failures/presentation_failure_mapper.dart';
import 'package:axiom/src/core/presentation/formatting/presentation_formatters.dart';
import 'package:axiom/src/core/presentation/tokens/design_tokens.dart';
import 'package:axiom/src/core/presentation/widgets/state/async_result_view.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/accounts/presentation/state/accounts_state.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Presentation mode for account balances.
enum AccountBalancePresentationMode {
  /// Dense representation intended for overview rows.
  compact,

  /// Full representation intended for account details.
  detailed,
}

/// Displays current account value in both account denomination and valuation
/// currency.
///
/// Financial arithmetic is deliberately not performed here. Values come from
/// the account valuation application service.
///
/// ## Semantics
///
/// Incoming amounts are rendered as positive values and outgoing amounts as
/// negative values.
///
/// ## Contract
///
/// Asset precision is taken from the corresponding [Asset].
final class AccountBalancePresentation extends ConsumerWidget {
  /// Creates account balance presentation.
  const AccountBalancePresentation({
    required this.accountId,
    this.mode = AccountBalancePresentationMode.compact,
    super.key,
  });

  final AccountId accountId;
  final AccountBalancePresentationMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(accountValuationPresentationProvider(accountId));

    return switch (mode) {
      AccountBalancePresentationMode.compact => _buildCompact(
        context,
        ref,
        value,
      ),
      AccountBalancePresentationMode.detailed => _buildDetailed(
        context,
        ref,
        value,
      ),
    };
  }

  Widget _buildCompact(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<Result<AccountValuationPresentationData, BaseFailure>> value,
  ) {
    final mapper = const PresentationFailureMapper();

    return value.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      loading: () => Semantics(
        label: 'Loading account value',
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
          success: (data) => _CompactValue(data: data),
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

  Widget _buildDetailed(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<Result<AccountValuationPresentationData, BaseFailure>> value,
  ) {
    return AsyncResultView<AccountValuationPresentationData, BaseFailure>(
      value: value,
      loadingSemanticLabel: 'Loading account valuation',
      refreshSemanticLabel: 'Refreshing account valuation',
      onRetry: () {
        ref.invalidate(accountValuationPresentationProvider(accountId));
      },
      builder: (context, data) {
        final sameAsset =
            data.valuation.accountAmount.assetId ==
            data.valuation.valuationAmount.assetId;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AmountCard(
              label: 'Account value',
              amount: data.valuation.accountAmount,
              asset: data.denominationAsset,
            ),
            if (!sameAsset) ...[
              const SizedBox(height: AppSpacing.small),
              _AmountCard(
                label: 'Valuation',
                amount: data.valuation.valuationAmount,
                asset: data.valuationCurrency,
              ),
            ],
          ],
        );
      },
    );
  }
}

final class _CompactValue extends StatelessWidget {
  const _CompactValue({required this.data});

  final AccountValuationPresentationData data;

  @override
  Widget build(BuildContext context) {
    final primary = _formatAmount(
      context,
      data.valuation.accountAmount,
      data.denominationAsset,
    );

    final sameAsset =
        data.valuation.accountAmount.assetId ==
        data.valuation.valuationAmount.assetId;

    final secondary = sameAsset
        ? null
        : _formatAmount(
            context,
            data.valuation.valuationAmount,
            data.valuationCurrency,
          );

    final theme = Theme.of(context);

    return Semantics(
      label: secondary == null
          ? 'Account value $primary'
          : 'Account value $primary, valuation $secondary',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              primary,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.end,
            ),
            if (secondary != null)
              Text(
                secondary,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.end,
              ),
          ],
        ),
      ),
    );
  }
}

final class _AmountCard extends StatelessWidget {
  const _AmountCard({
    required this.label,
    required this.amount,
    required this.asset,
  });

  final String label;
  final AssetAmount amount;
  final Asset asset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formatted = _formatAmount(context, amount, asset);

    return Semantics(
      label: '$label: $formatted',
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
                  label,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _formatAmount(BuildContext context, AssetAmount amount, Asset asset) {
  final signedAmount = amount.isOutgoing ? -amount.amount : amount.amount;

  final formatted = PresentationFormatters.of(
    context,
  ).numbers.decimal(signedAmount, maximumFractionDigits: asset.decimalPlaces);

  return '$formatted ${asset.code.value}';
}
