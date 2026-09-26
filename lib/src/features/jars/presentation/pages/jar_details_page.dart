import 'package:auto_route/auto_route.dart';
import 'package:axiom/src/core/identity/ids/jar_id.dart';
import 'package:axiom/src/core/presentation/navigation/app_router.gr.dart';
import 'package:axiom/src/core/presentation/tokens/design_tokens.dart';
import 'package:axiom/src/core/presentation/widgets/content/app_content.dart';
import 'package:axiom/src/core/presentation/widgets/entity/entity_visual.dart';
import 'package:axiom/src/core/presentation/widgets/state/async_result_view.dart';
import 'package:axiom/src/features/jars/domain/entities/jar.dart';
import 'package:axiom/src/features/jars/domain/enums/jar_kind.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_failure.dart';
import 'package:axiom/src/features/jars/presentation/state/jar_mutations.dart';
import 'package:axiom/src/features/jars/presentation/state/jars_state.dart';
import 'package:axiom/src/features/jars/presentation/widgets/jar_allocations.dart';
import 'package:axiom/src/features/jars/presentation/widgets/jar_progress_view.dart';
import 'package:axiom/src/features/jars/presentation/widgets/jar_transaction_history.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Displays details and derived financial data for one jar.
@RoutePage()
final class JarDetailsPage extends ConsumerWidget {
  /// Creates the jar details page.
  const JarDetailsPage({@PathParam('jarId') required this.jarId, super.key});

  final String jarId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parsedId = _parseJarId(jarId);

    if (parsedId == null) {
      return const _InvalidJarPage();
    }

    final value = ref.watch(jarProvider(parsedId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Jar'),
        actions: [
          IconButton(
            tooltip: 'Edit jar',
            onPressed: () {
              context.router.push(EditJarRoute(jarId: parsedId.value));
            },
            icon: const Icon(Symbols.edit_rounded),
          ),
        ],
      ),
      body: AsyncResultView<Jar?, JarFailure>(
        value: value,
        isEmpty: (jar) => jar == null,
        emptyTitle: 'Jar not found',
        emptyMessage: 'This jar is no longer available.',
        onRetry: () {
          ref.invalidate(jarProvider(parsedId));
        },
        builder: (context, jar) {
          if (jar == null) {
            return const SizedBox.shrink();
          }

          return _JarDetails(jar: jar);
        },
      ),
    );
  }
}

final class _JarDetails extends ConsumerWidget {
  const _JarDetails({required this.jar});

  final Jar jar;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return ListView(
      children: [
        AppContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  EntityVisual(
                    icon: jar.icon,
                    color: jar.color,
                    size: AppSize.entityVisualLarge,
                  ),
                  const SizedBox(width: AppSpacing.medium),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(jar.name, style: theme.textTheme.headlineSmall),
                        const SizedBox(height: AppSpacing.xxSmall),
                        Text(
                          [
                            _kindLabel(jar.kind),
                            if (jar.isArchived) 'Archived',
                          ].join(' · '),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (jar.description != null) ...[
                          const SizedBox(height: AppSpacing.small),
                          Text(jar.description!),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.large),
              JarProgressView(jarId: jar.id),
              const SizedBox(height: AppSpacing.medium),
              JarAllocations(jarId: jar.id),
              const SizedBox(height: AppSpacing.large),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Transaction history',
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xSmall),
              JarTransactionHistory(jarId: jar.id),
              const SizedBox(height: AppSpacing.large),
              OutlinedButton.icon(
                onPressed: () => _changeArchiveState(context, ref),
                icon: Icon(
                  jar.isArchived
                      ? Symbols.unarchive_rounded
                      : Symbols.archive_rounded,
                ),
                label: Text(jar.isArchived ? 'Reactivate jar' : 'Archive jar'),
              ),
              const SizedBox(height: AppSpacing.large),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _changeArchiveState(BuildContext context, WidgetRef ref) async {
    final result = jar.isArchived
        ? await executeUnarchiveJar(ref, jar.id)
        : await executeArchiveJar(ref, jar.id);

    if (!context.mounted || result == null) {
      return;
    }

    if (result.isFailure) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            jar.isArchived
                ? 'The jar could not be reactivated.'
                : 'The jar could not be archived.',
          ),
        ),
      );
    }
  }
}

final class _InvalidJarPage extends StatelessWidget {
  const _InvalidJarPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Jar')),
      body: const Center(child: Text('The jar identifier is invalid.')),
    );
  }
}

JarId? _parseJarId(String value) {
  try {
    return JarId.fromString(value);
  } on ArgumentError {
    return null;
  }
}

String _kindLabel(JarKind kind) {
  return switch (kind) {
    JarKind.savingsGoal => 'Savings goal',
    JarKind.sinkingFund => 'Sinking fund',
    JarKind.reserve => 'Reserve',
  };
}
