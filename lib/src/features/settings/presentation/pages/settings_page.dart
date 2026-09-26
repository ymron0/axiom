import 'package:auto_route/auto_route.dart';
import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/presentation/navigation/app_router.gr.dart';
import 'package:axiom/src/core/presentation/tokens/design_tokens.dart';
import 'package:axiom/src/core/presentation/widgets/content/app_content.dart';
import 'package:axiom/src/core/presentation/widgets/state/async_result_view.dart';
import 'package:axiom/src/features/settings/domain/entities/settings.dart';
import 'package:axiom/src/features/settings/domain/enums/planned_transaction_generation_horizon.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/experimental/mutation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../core/presentation/mutations/result_mutation_state.dart';
import '../mutations/settings_mutations.dart';
import '../state/settings_state.dart';

/// Main settings and reference-data destination.
@RoutePage()
final class SettingsPage extends ConsumerWidget {
  /// Creates the settings page.
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(settingsScreenDataProvider);
    final mutationState = ref.watch(updateSettingsMutation);
    final updating = mutationState is MutationPending;

    ref.listen(updateSettingsMutation, (previous, next) {
      final failure = resultMutationFailure(next);

      if (failure == null || !context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message)));
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: AsyncResultView<SettingsScreenData, BaseFailure>(
        value: value,
        onRetry: () {
          ref.invalidate(settingsScreenDataProvider);
        },
        builder: (context, data) {
          return ListView(
            children: [
              AppContent(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!data.isInitialized) ...[
                      const _SetupRequiredCard(),
                      const SizedBox(height: AppSpacing.large),
                    ],
                    _SettingsSection(
                      title: 'General',
                      children: [
                        ListTile(
                          leading: const Icon(
                            Symbols.currency_exchange_rounded,
                          ),
                          title: const Text('Valuation currency'),
                          subtitle: Text(
                            data.valuationCurrency == null
                                ? 'Choose the application-wide valuation currency'
                                : '${data.valuationCurrency!.code.value} · '
                                      '${data.valuationCurrency!.name}',
                          ),
                          trailing: const Icon(Symbols.chevron_right_rounded),
                          onTap: () {
                            context.router.push(const ValuationCurrencyRoute());
                          },
                        ),
                      ],
                    ),
                    if (data.settings != null) ...[
                      const SizedBox(height: AppSpacing.large),
                      _TransactionSettingsSection(
                        settings: data.settings!,
                        enabled: !updating,
                        onChanged: (updated) {
                          executeUpdateSettings(ref, updated);
                        },
                      ),
                    ],
                    const SizedBox(height: AppSpacing.large),
                    _SettingsSection(
                      title: 'Reference data',
                      children: [
                        ListTile(
                          leading: const Icon(Symbols.payments_rounded),
                          title: const Text('Assets'),
                          subtitle: const Text(
                            'Currencies, crypto, stocks and commodities',
                          ),
                          trailing: const Icon(Symbols.chevron_right_rounded),
                          onTap: () {
                            context.router.push(const AssetManagementRoute());
                          },
                        ),
                        ListTile(
                          leading: const Icon(Symbols.storefront_rounded),
                          title: const Text('Merchants'),
                          subtitle: const Text(
                            'Create, archive and maintain merchants',
                          ),
                          trailing: const Icon(Symbols.chevron_right_rounded),
                          onTap: () {
                            context.router.push(
                              const MerchantManagementRoute(),
                            );
                          },
                        ),
                        ListTile(
                          leading: const Icon(Symbols.monitoring_rounded),
                          title: const Text('Rate status'),
                          subtitle: const Text(
                            'Inspect the latest persisted USD observations',
                          ),
                          trailing: const Icon(Symbols.chevron_right_rounded),
                          onTap: () {
                            context.router.push(const RateStatusRoute());
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.large),
                    _SettingsSection(
                      title: 'Data',
                      children: [
                        ListTile(
                          leading: const Icon(Symbols.database_rounded),
                          title: const Text('Data management'),
                          subtitle: const Text(
                            'Storage overview and application reset',
                          ),
                          trailing: const Icon(Symbols.chevron_right_rounded),
                          onTap: () {
                            context.router.push(const DataManagementRoute());
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

final class _SetupRequiredCard extends StatelessWidget {
  const _SetupRequiredCard();

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Semantics(
      container: true,
      label:
          'Setup required. Choose a valuation currency before using financial features.',
      child: Card(
        color: colors.secondaryContainer,
        child: const Padding(
          padding: EdgeInsets.all(AppSpacing.medium),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Symbols.info_rounded),
              SizedBox(width: AppSpacing.small),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Setup required',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: AppSpacing.xxSmall),
                    Text(
                      'Choose a valuation currency before using financial '
                      'features.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _TransactionSettingsSection extends StatelessWidget {
  const _TransactionSettingsSection({
    required this.settings,
    required this.enabled,
    required this.onChanged,
  });

  final Settings settings;
  final bool enabled;
  final ValueChanged<Settings> onChanged;

  @override
  Widget build(BuildContext context) {
    return _SettingsSection(
      title: 'Transactions',
      children: [
        ListTile(
          leading: const Icon(Symbols.event_repeat_rounded),
          title: const Text('Planned transaction horizon'),
          subtitle: const Text(
            'How far recurring transactions are materialized',
          ),
          trailing: DropdownButton<PlannedTransactionGenerationHorizon>(
            value: settings.plannedTransactionGenerationHorizon,
            onChanged: !enabled
                ? null
                : (value) {
                    if (value == null ||
                        value == settings.plannedTransactionGenerationHorizon) {
                      return;
                    }

                    onChanged(
                      settings.copyWith(
                        plannedTransactionGenerationHorizon: value,
                      ),
                    );
                  },
            items: PlannedTransactionGenerationHorizon.values
                .map(
                  (value) =>
                      DropdownMenuItem(value: value, child: Text(value.label)),
                )
                .toList(growable: false),
          ),
        ),
        SwitchListTile(
          secondary: const Icon(Symbols.account_balance_wallet_rounded),
          title: const Text('Allow over-budget transactions'),
          subtitle: const Text(
            'Transactions may exceed category budget limits',
          ),
          value: settings.allowOverbudgetTransactions,
          onChanged: !enabled
              ? null
              : (value) {
                  onChanged(
                    settings.copyWith(allowOverbudgetTransactions: value),
                  );
                },
        ),
        SwitchListTile(
          secondary: const Icon(Symbols.savings_rounded),
          title: const Text('Allow negative jar balances'),
          subtitle: const Text(
            'Allocations may create or worsen a negative jar balance',
          ),
          value: settings.allowNegativeJarBalances,
          onChanged: !enabled
              ? null
              : (value) {
                  onChanged(settings.copyWith(allowNegativeJarBalances: value));
                },
        ),
      ],
    );
  }
}

final class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.small),
            child: Text(title, style: Theme.of(context).textTheme.titleSmall),
          ),
          const SizedBox(height: AppSpacing.xSmall),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(children: children),
          ),
        ],
      ),
    );
  }
}

extension on PlannedTransactionGenerationHorizon {
  String get label {
    return switch (this) {
      PlannedTransactionGenerationHorizon.nextOccurrence => 'Next',
      PlannedTransactionGenerationHorizon.oneYear => '1 year',
      PlannedTransactionGenerationHorizon.twoYears => '2 years',
    };
  }
}
