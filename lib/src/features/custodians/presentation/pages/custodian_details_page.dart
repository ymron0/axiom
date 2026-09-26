import 'package:auto_route/auto_route.dart';
import 'package:axiom/src/core/identity/ids/custodian_id.dart';
import 'package:axiom/src/core/presentation/navigation/app_router.gr.dart';
import 'package:axiom/src/core/presentation/tokens/design_tokens.dart';
import 'package:axiom/src/core/presentation/widgets/content/app_content.dart';
import 'package:axiom/src/core/presentation/widgets/content/app_section_header.dart';
import 'package:axiom/src/core/presentation/widgets/entity/entity_visual.dart';
import 'package:axiom/src/core/presentation/widgets/list/app_list_item.dart';
import 'package:axiom/src/core/presentation/widgets/state/async_result_view.dart';
import 'package:axiom/src/features/accounts/domain/entities/account.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_failure.dart';
import 'package:axiom/src/features/accounts/presentation/widgets/account_balance_presentation.dart';
import 'package:axiom/src/features/custodians/domain/entities/custodian.dart';
import 'package:axiom/src/features/custodians/domain/enums/custodian_kind.dart';
import 'package:axiom/src/features/custodians/domain/failures/custodian_failure.dart';
import 'package:axiom/src/features/custodians/presentation/state/custodians_state.dart';
import 'package:axiom/src/features/custodians/presentation/widgets/custodian_valuation_presentation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Displays one custodian and its accounts.
@RoutePage()
final class CustodianDetailsPage extends ConsumerWidget {
  /// Creates the page.
  const CustodianDetailsPage({
    @PathParam('custodianId') required this.custodianId,
    super.key,
  });

  final String custodianId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parsedId = _parseCustodianId(custodianId);

    if (parsedId == null) {
      return const _InvalidCustodianPage();
    }

    final value = ref.watch(custodianProvider(parsedId));

    return Scaffold(
      appBar: AppBar(title: const Text('Custodian')),
      body: AsyncResultView<Custodian?, CustodianFailure>(
        value: value,
        isEmpty: (custodian) => custodian == null,
        emptyTitle: 'Custodian not found',
        emptyMessage: 'This custodian is no longer available.',
        onRetry: () {
          ref.invalidate(custodianProvider(parsedId));
        },
        builder: (context, custodian) {
          if (custodian == null) {
            return const SizedBox.shrink();
          }

          return _CustodianDetails(custodian: custodian);
        },
      ),
    );
  }
}

final class _CustodianDetails extends ConsumerWidget {
  const _CustodianDetails({required this.custodian});

  final Custodian custodian;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final accounts = ref.watch(custodianAccountsProvider(custodian.id));

    return ListView(
      children: [
        AppContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  EntityVisual(
                    icon: custodian.icon,
                    color: custodian.color,
                    logo: custodian.logo,
                    size: AppSize.entityVisualLarge,
                  ),
                  const SizedBox(width: AppSpacing.medium),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          custodian.name,
                          style: theme.textTheme.headlineSmall,
                        ),
                        const SizedBox(height: AppSpacing.xxSmall),
                        Text(
                          _custodianKindLabel(custodian.kind),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Edit custodian',
                    onPressed: () async {
                      await context.router.push(
                        EditCustodianRoute(custodianId: custodian.id.value),
                      );

                      ref.invalidate(custodianProvider(custodian.id));
                      ref.invalidate(custodianValuationProvider(custodian.id));
                    },
                    icon: const Icon(Symbols.edit_rounded),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.large),
              CustodianValuationPresentation(
                custodianId: custodian.id,
                mode: CustodianValuationPresentationMode.detailed,
              ),
              const SizedBox(height: AppSpacing.large),
              const AppSectionHeader(title: 'Accounts'),
              const SizedBox(height: AppSpacing.xSmall),
              AsyncResultView<List<Account>, AccountFailure>(
                value: accounts,
                isEmpty: (accounts) => accounts.isEmpty,
                emptyTitle: 'No accounts',
                emptyMessage:
                    'This custodian does not currently hold any accounts.',
                onRetry: () {
                  ref.invalidate(custodianAccountsProvider(custodian.id));
                },
                builder: (context, loadedAccounts) {
                  return Column(
                    children: [
                      for (
                        var index = 0;
                        index < loadedAccounts.length;
                        index++
                      ) ...[
                        _AccountItem(account: loadedAccounts[index]),
                        if (index < loadedAccounts.length - 1)
                          const Divider(height: 1),
                      ],
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

final class _AccountItem extends StatelessWidget {
  const _AccountItem({required this.account});

  final Account account;

  @override
  Widget build(BuildContext context) {
    return AppListItem(
      leading: EntityVisual(
        icon: account.icon,
        color: account.color,
        logo: account.logo,
      ),
      title: Text(account.name),
      subtitle: account.reference == null ? null : Text(account.reference!),
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 132),
        child: AccountBalancePresentation(accountId: account.id),
      ),
      onTap: () {
        context.router.push(AccountDetailsRoute(accountId: account.id.value));
      },
    );
  }
}

final class _InvalidCustodianPage extends StatelessWidget {
  const _InvalidCustodianPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Custodian')),
      body: const Center(child: Text('The custodian identifier is invalid.')),
    );
  }
}

CustodianId? _parseCustodianId(String value) {
  try {
    return CustodianId.fromString(value);
  } on ArgumentError {
    return null;
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
