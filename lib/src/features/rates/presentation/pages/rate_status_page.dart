import 'package:auto_route/auto_route.dart';
import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/presentation/tokens/design_tokens.dart';
import 'package:axiom/src/core/presentation/widgets/content/app_content.dart';
import 'package:axiom/src/core/presentation/widgets/list/app_list_item.dart';
import 'package:axiom/src/core/presentation/widgets/state/async_result_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../state/rate_status_state.dart';

/// Displays persisted rate availability and financial timestamps.
@RoutePage()
final class RateStatusPage extends ConsumerWidget {
  /// Creates the rate-status page.
  const RateStatusPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(rateStatusProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rate status'),
        actions: [
          IconButton(
            tooltip: 'Reload persisted rates',
            onPressed: () {
              ref.invalidate(rateStatusProvider);
            },
            icon: const Icon(Symbols.refresh_rounded),
          ),
        ],
      ),
      body: AsyncResultView<RateStatusData, BaseFailure>(
        value: value,
        onRetry: () {
          ref.invalidate(rateStatusProvider);
        },
        builder: (context, data) {
          return ListView(
            children: [
              AppContent(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.medium),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Symbols.info_rounded),
                            const SizedBox(width: AppSpacing.small),
                            Expanded(
                              child: Text(
                                'Persisted rates are quoted in '
                                '${data.quoteCurrency.code.value}. '
                                'The timestamp shown below is the rate '
                                'effective time, not its storage time.',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.medium),
                    if (data.items.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(AppSpacing.medium),
                          child: Text('No assets require a persisted rate.'),
                        ),
                      )
                    else
                      Card(
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            for (final item in data.items)
                              _RateStatusRow(
                                item: item,
                                quoteCode: data.quoteCurrency.code.value,
                              ),
                          ],
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

final class _RateStatusRow extends StatelessWidget {
  const _RateStatusRow({required this.item, required this.quoteCode});

  final RateStatusItem item;
  final String quoteCode;

  @override
  Widget build(BuildContext context) {
    final rate = item.latestRate;

    if (rate == null) {
      return AppListItem(
        leading: Icon(
          Symbols.warning_rounded,
          color: Theme.of(context).colorScheme.error,
        ),
        title: Text('${item.asset.code.value} · ${item.asset.name}'),
        subtitle: Text('No persisted ${item.asset.code.value}/$quoteCode rate'),
        semanticLabel: '${item.asset.code.value}, no persisted rate',
      );
    }

    return AppListItem(
      leading: const Icon(Symbols.check_circle_rounded),
      title: Text('${item.asset.code.value} · ${item.asset.name}'),
      subtitle: Text(
        '1 ${item.asset.code.value} = '
        '${rate.rate} $quoteCode\n'
        'Effective ${_formatDateTime(context, rate.effectiveAt)}',
      ),
      semanticLabel:
          '${item.asset.code.value}, rate ${rate.rate} $quoteCode, '
          'effective ${_formatDateTime(context, rate.effectiveAt)}',
    );
  }
}

String _formatDateTime(BuildContext context, DateTime instant) {
  final local = instant.toLocal();
  final localizations = MaterialLocalizations.of(context);

  return '${localizations.formatMediumDate(local)} '
      '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
}
