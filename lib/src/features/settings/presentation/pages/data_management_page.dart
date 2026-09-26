import 'package:auto_route/auto_route.dart';
import 'package:axiom/src/core/persistence/application_data_service.dart';
import 'package:axiom/src/core/presentation/navigation/app_router.gr.dart';
import 'package:axiom/src/core/presentation/tokens/design_tokens.dart';
import 'package:axiom/src/core/presentation/widgets/content/app_content.dart';
import 'package:axiom/src/core/presentation/widgets/state/async_result_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../state/data_management_state.dart';

/// Displays persistence diagnostics and destructive data controls.
@RoutePage()
final class DataManagementPage extends ConsumerWidget {
  /// Creates the data-management page.
  const DataManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(applicationDataSummaryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Data management'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(applicationDataSummaryProvider);
            },
            icon: const Icon(Symbols.refresh_rounded),
          ),
        ],
      ),
      body: AsyncResultView<ApplicationDataSummary, ApplicationDataFailure>(
        value: value,
        onRetry: () {
          ref.invalidate(applicationDataSummaryProvider);
        },
        builder: (context, summary) {
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
                              '${summary.totalRecords}',
                              style: Theme.of(context).textTheme.headlineMedium,
                            ),
                            const Text('Persisted records'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.large),
                    _CountSection(
                      title: 'User financial data',
                      counts: summary.resettableCounts,
                      total: summary.resettableTotal,
                    ),
                    const SizedBox(height: AppSpacing.large),
                    _CountSection(
                      title: 'Reference data',
                      counts: summary.referenceDataCounts,
                      total: summary.referenceDataTotal,
                    ),
                    const SizedBox(height: AppSpacing.large),
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: ListTile(
                        leading: Icon(
                          Symbols.restart_alt_rounded,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        title: const Text('Reset application'),
                        subtitle: const Text(
                          'Remove settings and all user financial data',
                        ),
                        trailing: const Icon(Symbols.chevron_right_rounded),
                        onTap: () {
                          context.router.push(const ResetApplicationRoute());
                        },
                      ),
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

final class _CountSection extends StatelessWidget {
  const _CountSection({
    required this.title,
    required this.counts,
    required this.total,
  });

  final String title;
  final Map<String, int> counts;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '$title, $total records',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '$title · $total',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AppSpacing.xSmall),
          Card(
            child: Column(
              children: [
                for (final entry in counts.entries)
                  ListTile(
                    title: Text(_labelForStore(entry.key)),
                    trailing: Text('${entry.value}'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _labelForStore(String store) {
  return switch (store) {
    'assets' => 'Assets',
    'settings' => 'Settings',
    'rates' => 'Rates',
    'merchants' => 'Merchants',
    'transactions' => 'Transactions',
    'transactionSeries' => 'Transaction series',
    'accounts' => 'Accounts',
    'custodians' => 'Custodians',
    'categories' => 'Categories',
    'jars' => 'Jars',
    'tags' => 'Tags',
    'balanceSnapshots' => 'Balance snapshots',
    _ => store,
  };
}
