import 'package:auto_route/auto_route.dart';
import 'package:axiom/src/core/presentation/mutations/result_mutation_state.dart';
import 'package:axiom/src/core/presentation/navigation/app_router.gr.dart';
import 'package:axiom/src/core/presentation/tokens/design_tokens.dart';
import 'package:axiom/src/core/presentation/widgets/content/app_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/experimental/mutation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../mutations/data_management_mutations.dart';

/// Confirms and executes an application financial-data reset.
@RoutePage()
final class ResetApplicationPage extends ConsumerWidget {
  /// Creates the reset page.
  const ResetApplicationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(resetApplicationMutation);
    final failure = resultMutationFailure(state);
    final pending = state is MutationPending;

    ref.listen(resetApplicationMutation, (previous, next) {
      if (next case MutationSuccess(:final value) when value.isSuccess) {
        if (!context.mounted) {
          return;
        }

        context.router.replace(const ValuationCurrencyRoute());
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Reset application')),
      body: ListView(
        children: [
          AppContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Symbols.warning_rounded,
                  size: 48,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: AppSpacing.medium),
                Text(
                  'Reset user financial data?',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.medium),
                const Text(
                  'This permanently removes settings, merchants, accounts, '
                  'custodians, transactions, transaction series, categories, '
                  'jars, tags and balance snapshots.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.medium),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.medium),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Symbols.database_rounded),
                        const SizedBox(width: AppSpacing.small),
                        Expanded(
                          child: Text(
                            'Assets and rates are preserved so you can choose '
                            'a new valuation currency immediately after reset.',
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
                const SizedBox(height: AppSpacing.large),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                  ),
                  onPressed: pending
                      ? null
                      : () async {
                          final confirmed = await _confirmReset(context);

                          if (confirmed == true) {
                            await executeResetApplication(ref);
                          }
                        },
                  icon: pending
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Symbols.restart_alt_rounded),
                  label: const Text('Reset application'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<bool?> _confirmReset(BuildContext context) {
    final controller = TextEditingController();

    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            final confirmed = controller.text.trim() == 'RESET';

            return AlertDialog(
              title: const Text('Confirm reset'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Type RESET to confirm. This operation cannot be undone.',
                  ),
                  const SizedBox(height: AppSpacing.medium),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(
                      labelText: 'Confirmation',
                    ),
                    onChanged: (_) {
                      setState(() {});
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, false);
                  },
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: confirmed
                      ? () {
                          Navigator.pop(dialogContext, true);
                        }
                      : null,
                  child: const Text('Reset'),
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(controller.dispose);
  }
}
