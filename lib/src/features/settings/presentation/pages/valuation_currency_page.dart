import 'package:auto_route/auto_route.dart';
import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/presentation/mutations/result_mutation_state.dart';
import 'package:axiom/src/core/presentation/navigation/app_router.gr.dart';
import 'package:axiom/src/core/presentation/tokens/design_tokens.dart';
import 'package:axiom/src/core/presentation/widgets/content/app_content.dart';
import 'package:axiom/src/core/presentation/widgets/state/async_result_view.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/experimental/mutation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../mutations/settings_mutations.dart';
import '../state/settings_state.dart';

/// Displays or initializes the application valuation currency.
///
/// Once settings are initialized this screen is read-only. Changing the
/// valuation currency requires the reset workflow.
@RoutePage()
final class ValuationCurrencyPage extends ConsumerStatefulWidget {
  /// Creates the valuation-currency page.
  const ValuationCurrencyPage({super.key});

  @override
  ConsumerState<ValuationCurrencyPage> createState() =>
      _ValuationCurrencyPageState();
}

final class _ValuationCurrencyPageState
    extends ConsumerState<ValuationCurrencyPage> {
  AssetId? _selectedCurrencyId;

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(settingsScreenDataProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Valuation currency')),
      body: AsyncResultView<SettingsScreenData, BaseFailure>(
        value: data,
        onRetry: () {
          ref.invalidate(settingsScreenDataProvider);
        },
        builder: (context, settingsData) {
          final currency = settingsData.valuationCurrency;

          if (currency != null) {
            return _CurrentValuationCurrency(currency: currency);
          }

          return _buildInitialization(context);
        },
      ),
    );
  }

  Widget _buildInitialization(BuildContext context) {
    final options = ref.watch(valuationCurrencyOptionsProvider);
    final mutationState = ref.watch(initializeSettingsMutation);
    final failure = resultMutationFailure(mutationState);
    final pending = mutationState is MutationPending;

    ref.listen(initializeSettingsMutation, (previous, next) {
      if (next case MutationSuccess(:final value) when value.isSuccess) {
        if (context.mounted) {
          context.router.pop();
        }
      }
    });

    return AsyncResultView<List<Currency>, BaseFailure>(
      value: options,
      onRetry: () {
        ref.invalidate(valuationCurrencyOptionsProvider);
      },
      builder: (context, currencies) {
        return ListView(
          children: [
            AppContent(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Choose a currency',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.xSmall),
                  Text(
                    'This currency becomes the common reference for '
                    'cross-asset values, totals, budgets and jars.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppSpacing.medium),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.medium),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Symbols.lock_rounded),
                          const SizedBox(width: AppSpacing.small),
                          Expanded(
                            child: Text(
                              'After setup, the valuation currency cannot be '
                              'changed without resetting user financial data.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (failure != null) ...[
                    const SizedBox(height: AppSpacing.medium),
                    Material(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.medium),
                        child: Text(failure.message),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.medium),
                  if (currencies.isEmpty)
                    _NoCurrenciesCard(
                      onManageAssets: () {
                        context.router.push(const AssetManagementRoute());
                      },
                    )
                  else
                    RadioGroup<AssetId>(
                      groupValue: _selectedCurrencyId,
                      onChanged: (value) {
                        setState(() {
                          _selectedCurrencyId = value;
                        });
                      },
                      child: Card(
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            for (final currency in currencies)
                              RadioListTile<AssetId>(
                                value: currency.id,
                                enabled: !pending,
                                title: Text(
                                  '${currency.code.value} · ${currency.name}',
                                ),
                                subtitle: currency.symbol == null
                                    ? null
                                    : Text(currency.symbol!),
                              ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.large),
                  FilledButton(
                    onPressed:
                        pending ||
                            _selectedCurrencyId == null ||
                            currencies.isEmpty
                        ? null
                        : () {
                            executeInitializeSettings(
                              ref,
                              _selectedCurrencyId!,
                            );
                          },
                    child: pending
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Use this currency'),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

final class _CurrentValuationCurrency extends StatelessWidget {
  const _CurrentValuationCurrency({required this.currency});

  final Currency currency;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        AppContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.large),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currency.code.value,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: AppSpacing.xxSmall),
                      Text(
                        currency.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.medium),
                      _DetailRow(
                        label: 'Symbol',
                        value: currency.symbol ?? '—',
                      ),
                      _DetailRow(
                        label: 'Decimal places',
                        value: '${currency.decimalPlaces}',
                      ),
                      _DetailRow(label: 'Asset ID', value: currency.id.value),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.medium),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.medium),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Symbols.lock_rounded),
                      const SizedBox(width: AppSpacing.small),
                      Expanded(
                        child: Text(
                          'The valuation currency is immutable after setup. '
                          'Changing it requires resetting user financial data.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.large),
              OutlinedButton.icon(
                onPressed: () {
                  context.router.push(const ResetApplicationRoute());
                },
                icon: const Icon(Symbols.restart_alt_rounded),
                label: const Text('Reset to choose another currency'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

final class _NoCurrenciesCard extends StatelessWidget {
  const _NoCurrenciesCard({required this.onManageAssets});

  final VoidCallback onManageAssets;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.medium),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'No currency assets are available.',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSpacing.xSmall),
            const Text(
              'Create at least one Currency asset before initializing '
              'settings.',
            ),
            const SizedBox(height: AppSpacing.medium),
            OutlinedButton(
              onPressed: onManageAssets,
              child: const Text('Manage assets'),
            ),
          ],
        ),
      ),
    );
  }
}

final class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xSmall),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}
