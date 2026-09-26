import 'package:auto_route/auto_route.dart';
import 'package:axiom/src/core/presentation/navigation/app_router.gr.dart';
import 'package:axiom/src/core/presentation/tokens/design_tokens.dart';
import 'package:axiom/src/core/presentation/widgets/content/app_content.dart';
import 'package:axiom/src/core/presentation/widgets/entity/entity_visual.dart';
import 'package:axiom/src/core/presentation/widgets/list/app_list_item.dart';
import 'package:axiom/src/core/presentation/widgets/state/async_result_view.dart';
import 'package:axiom/src/features/accounts/domain/entities/account.dart';
import 'package:axiom/src/features/accounts/domain/enums/account_kind.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_failure.dart';
import 'package:axiom/src/features/accounts/presentation/state/accounts_state.dart';
import 'package:axiom/src/features/accounts/presentation/widgets/account_balance_presentation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Primary accounts destination.
@RoutePage()
final class AccountsPage extends ConsumerWidget {
  /// Creates the accounts page.
  const AccountsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(accountsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounts'),
        actions: [
          IconButton(
            tooltip: 'Custodians',
            onPressed: () {
              context.router.push(const CustodiansRoute());
            },
            icon: const Icon(Symbols.account_balance_rounded),
          ),
          const SizedBox(width: AppSpacing.xSmall),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(accountsProvider);
          await ref.read(accountsProvider.future);
        },
        child: AsyncResultView<List<Account>, AccountFailure>(
          value: accounts,
          isEmpty: (value) => value.isEmpty,
          emptyBuilder: (context) {
            return EmptyStateView(
              icon: Symbols.account_balance_wallet_rounded,
              title: 'No accounts yet',
              message:
                  'Create an account to start tracking balances and activity.',
              actionLabel: 'Create account',
              onAction: () {
                context.router.push(const CreateAccountRoute());
              },
            );
          },
          onRetry: () => ref.invalidate(accountsProvider),
          loadingSemanticLabel: 'Loading accounts',
          refreshSemanticLabel: 'Refreshing accounts',
          builder: (context, loadedAccounts) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                AppContent(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.xSmall,
                  ),
                  child: Column(
                    children: [
                      for (
                        var index = 0;
                        index < loadedAccounts.length;
                        index++
                      ) ...[
                        _AccountItem(account: loadedAccounts[index]),
                        if (index < loadedAccounts.length - 1)
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
        heroTag: 'create-account',
        onPressed: () {
          context.router.push(const CreateAccountRoute());
        },
        icon: const Icon(Symbols.add_rounded),
        label: const Text('Account'),
      ),
    );
  }
}

final class _AccountItem extends ConsumerWidget {
  const _AccountItem({required this.account});

  final Account account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final custodian = ref.watch(accountCustodianProvider(account.custodianId));

    final custodianName = custodian.value?.valueOrNull?.name;

    final subtitleParts = <String>[
      ?custodianName,
      _accountKindLabel(account.kind),
      if (account.reference != null) account.reference!,
    ];

    return AppListItem(
      leading: EntityVisual(
        icon: account.icon,
        color: account.color,
        logo: account.logo,
      ),
      title: Text(account.name),
      subtitle: Text(subtitleParts.join(' · ')),
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 132),
        child: AccountBalancePresentation(accountId: account.id),
      ),
      semanticLabel: '${account.name}, ${subtitleParts.join(', ')}',
      onTap: () {
        context.router.push(AccountDetailsRoute(accountId: account.id.value));
      },
    );
  }
}

String _accountKindLabel(AccountKind kind) {
  return switch (kind) {
    AccountKind.cash => 'Cash',
    AccountKind.checking => 'Checking',
    AccountKind.creditCard => 'Credit card',
    AccountKind.cryptoWallet => 'Crypto wallet',
    AccountKind.digitalWallet => 'Digital wallet',
    AccountKind.investment => 'Investment',
    AccountKind.savings => 'Savings',
  };
}
