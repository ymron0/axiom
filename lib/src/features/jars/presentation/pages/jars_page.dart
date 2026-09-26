import 'package:auto_route/auto_route.dart';
import 'package:axiom/src/core/presentation/navigation/app_router.gr.dart';
import 'package:axiom/src/core/presentation/tokens/design_tokens.dart';
import 'package:axiom/src/core/presentation/widgets/content/app_content.dart';
import 'package:axiom/src/core/presentation/widgets/entity/entity_visual.dart';
import 'package:axiom/src/core/presentation/widgets/list/app_list_item.dart';
import 'package:axiom/src/core/presentation/widgets/state/async_result_view.dart';
import 'package:axiom/src/features/jars/domain/entities/jar.dart';
import 'package:axiom/src/features/jars/domain/enums/jar_kind.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_failure.dart';
import 'package:axiom/src/features/jars/presentation/state/jars_state.dart';
import 'package:axiom/src/features/jars/presentation/widgets/jar_progress_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Overview of allocation jars.
@RoutePage()
final class JarsPage extends ConsumerStatefulWidget {
  /// Creates the jars page.
  const JarsPage({super.key});

  @override
  ConsumerState<JarsPage> createState() => _JarsPageState();
}

final class _JarsPageState extends ConsumerState<JarsPage> {
  var _showArchived = false;

  @override
  Widget build(BuildContext context) {
    final value = _showArchived
        ? ref.watch(allJarsProvider)
        : ref.watch(jarsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Jars'),
        actions: [
          PopupMenuButton<_JarMenuAction>(
            tooltip: 'More jar options',
            onSelected: (action) {
              switch (action) {
                case _JarMenuAction.showArchived:
                  setState(() {
                    _showArchived = !_showArchived;
                  });
              }
            },
            itemBuilder: (context) => [
              CheckedPopupMenuItem(
                value: _JarMenuAction.showArchived,
                checked: _showArchived,
                child: const Text('Show archived'),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          if (_showArchived) {
            ref.invalidate(allJarsProvider);
            await ref.read(allJarsProvider.future);
          } else {
            ref.invalidate(jarsProvider);
            await ref.read(jarsProvider.future);
          }
        },
        child: AsyncResultView<List<Jar>, JarFailure>(
          value: value,
          isEmpty: (items) => items.isEmpty,
          emptyBuilder: (context) {
            return EmptyStateView(
              icon: Symbols.savings_rounded,
              title: 'No jars yet',
              message:
                  'Create a jar to reserve money or track progress '
                  'toward a financial goal.',
              actionLabel: 'Create jar',
              onAction: () {
                context.router.push(const CreateJarRoute());
              },
            );
          },
          onRetry: () {
            if (_showArchived) {
              ref.invalidate(allJarsProvider);
            } else {
              ref.invalidate(jarsProvider);
            }
          },
          loadingSemanticLabel: 'Loading jars',
          refreshSemanticLabel: 'Refreshing jars',
          builder: (context, jars) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                AppContent(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.xSmall,
                  ),
                  child: Column(
                    children: [
                      for (var index = 0; index < jars.length; index++) ...[
                        _JarItem(jar: jars[index]),
                        if (index < jars.length - 1)
                          const Divider(
                            height: 1,
                            indent: AppSpacing.medium + AppSize.entityVisual,
                          ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 88),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'create-jar',
        onPressed: () {
          context.router.push(const CreateJarRoute());
        },
        icon: const Icon(Symbols.add_rounded),
        label: const Text('Jar'),
      ),
    );
  }
}

enum _JarMenuAction { showArchived }

final class _JarItem extends StatelessWidget {
  const _JarItem({required this.jar});

  final Jar jar;

  @override
  Widget build(BuildContext context) {
    final subtitle = <String>[
      _kindLabel(jar.kind),
      if (jar.isArchived) 'Archived',
    ];

    return AppListItem(
      leading: EntityVisual(icon: jar.icon, color: jar.color),
      title: Text(jar.name),
      subtitle: Text(subtitle.join(' · ')),
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 132),
        child: JarProgressView(jarId: jar.id, compact: true),
      ),
      semanticLabel: '${jar.name}, ${subtitle.join(', ')}',
      onTap: () {
        context.router.push(JarDetailsRoute(jarId: jar.id.value));
      },
    );
  }
}

String _kindLabel(JarKind kind) {
  return switch (kind) {
    JarKind.savingsGoal => 'Savings goal',
    JarKind.sinkingFund => 'Sinking fund',
    JarKind.reserve => 'Reserve',
  };
}
