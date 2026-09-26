import 'package:auto_route/auto_route.dart';
import 'package:axiom/src/core/presentation/navigation/app_router.gr.dart';
import 'package:axiom/src/core/presentation/tokens/design_tokens.dart';
import 'package:axiom/src/core/presentation/widgets/content/app_content.dart';
import 'package:axiom/src/core/presentation/widgets/entity/entity_visual.dart';
import 'package:axiom/src/core/presentation/widgets/list/app_list_item.dart';
import 'package:axiom/src/core/presentation/widgets/state/async_result_view.dart';
import 'package:axiom/src/features/custodians/domain/entities/custodian.dart';
import 'package:axiom/src/features/custodians/domain/enums/custodian_kind.dart';
import 'package:axiom/src/features/custodians/domain/failures/custodian_failure.dart';
import 'package:axiom/src/features/custodians/presentation/state/custodians_state.dart';
import 'package:axiom/src/features/custodians/presentation/widgets/custodian_valuation_presentation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Overview of financial custodians.
@RoutePage()
final class CustodiansPage extends ConsumerWidget {
  /// Creates the custodians page.
  const CustodiansPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(custodiansProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Custodians')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(custodiansProvider);
          await ref.read(custodiansProvider.future);
        },
        child: AsyncResultView<List<Custodian>, CustodianFailure>(
          value: value,
          isEmpty: (custodians) => custodians.isEmpty,
          emptyBuilder: (context) {
            return EmptyStateView(
              icon: Symbols.account_balance_rounded,
              title: 'No custodians yet',
              message:
                  'Add a bank, broker, wallet, exchange, or other place '
                  'where accounts are held.',
              actionLabel: 'Create custodian',
              onAction: () {
                context.router.push(const CreateCustodianRoute());
              },
            );
          },
          onRetry: () => ref.invalidate(custodiansProvider),
          builder: (context, loaded) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                AppContent(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.xSmall,
                  ),
                  child: Column(
                    children: [
                      for (var index = 0; index < loaded.length; index++) ...[
                        _CustodianItem(custodian: loaded[index]),
                        if (index < loaded.length - 1)
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
        heroTag: 'create-custodian',
        onPressed: () {
          context.router.push(const CreateCustodianRoute());
        },
        icon: const Icon(Symbols.add_rounded),
        label: const Text('Custodian'),
      ),
    );
  }
}

final class _CustodianItem extends StatelessWidget {
  const _CustodianItem({required this.custodian});

  final Custodian custodian;

  @override
  Widget build(BuildContext context) {
    return AppListItem(
      leading: EntityVisual(
        icon: custodian.icon,
        color: custodian.color,
        logo: custodian.logo,
      ),
      title: Text(custodian.name),
      subtitle: Text(_custodianKindLabel(custodian.kind)),
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 132),
        child: CustodianValuationPresentation(custodianId: custodian.id),
      ),
      semanticLabel:
          '${custodian.name}, '
          '${_custodianKindLabel(custodian.kind)}',
      onTap: () {
        context.router.push(
          CustodianDetailsRoute(custodianId: custodian.id.value),
        );
      },
    );
  }
}

String _custodianKindLabel(CustodianKind kind) {
  return switch (kind) {
    CustodianKind.bank => 'Bank',
    CustodianKind.broker => 'Broker',
    CustodianKind.creditProvider => 'Credit provider',
    CustodianKind.digitalWallet => 'Digital wallet',
    CustodianKind.exchange => 'Exchange',
    CustodianKind.selfCustody => 'Self custody',
  };
}
