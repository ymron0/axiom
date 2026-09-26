import 'package:auto_route/auto_route.dart';
import 'package:axiom/src/core/presentation/navigation/app_router.gr.dart';
import 'package:axiom/src/core/presentation/tokens/design_tokens.dart';
import 'package:axiom/src/core/presentation/widgets/content/app_content.dart';
import 'package:axiom/src/core/presentation/widgets/list/app_list_item.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Primary destination for secondary application areas.
@RoutePage()
final class MorePage extends StatelessWidget {
  /// Creates the more page.
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        children: [
          AppContent(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xSmall),
            child: Column(
              children: [
                AppListItem(
                  leading: const Icon(
                    Symbols.savings_rounded,
                    size: AppSize.iconLarge,
                  ),
                  title: const Text('Jars'),
                  subtitle: const Text(
                    'Savings goals, sinking funds and reserves',
                  ),
                  trailing: const Icon(Symbols.chevron_right_rounded),
                  semanticLabel:
                      'Jars, savings goals, sinking funds and reserves',
                  onTap: () {
                    context.router.push(const JarsRoute());
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
