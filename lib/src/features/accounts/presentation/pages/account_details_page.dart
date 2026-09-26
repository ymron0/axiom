import 'package:auto_route/auto_route.dart';
import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/presentation/navigation/app_router.gr.dart';
import 'package:axiom/src/core/presentation/tokens/design_tokens.dart';
import 'package:axiom/src/core/presentation/widgets/content/app_content.dart';
import 'package:axiom/src/core/presentation/widgets/entity/entity_visual.dart';
import 'package:axiom/src/core/presentation/widgets/state/async_result_view.dart';
import 'package:axiom/src/features/accounts/domain/entities/account.dart';
import 'package:axiom/src/features/accounts/domain/enums/account_kind.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_failure.dart';
import 'package:axiom/src/features/accounts/presentation/state/accounts_state.dart';
import 'package:axiom/src/features/accounts/presentation/widgets/account_balance_presentation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Displays one account and its derived current value.
@RoutePage()
final class AccountDetailsPage extends ConsumerWidget {
  /// Creates the account details page.
  const AccountDetailsPage({
    @PathParam('accountId') required this.accountId,
    super.key,
  });

  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parsedId = _parseAccountId(accountId);

    if (parsedId == null) {
      return const _InvalidAccountPage();
    }

    final accountValue = ref.watch(accountProvider(parsedId));

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: AsyncResultView<Account?, AccountFailure>(
        value: accountValue,
        isEmpty: (value) => value == null,
        emptyTitle: 'Account not found',
        emptyMessage: 'This account is no longer available.',
        onRetry: () => ref.invalidate(accountProvider(parsedId)),
        builder: (context, account) {
          if (account == null) {
            return const SizedBox.shrink();
          }

          return _AccountDetails(account: account);
        },
      ),
    );
  }
}

final class _AccountDetails extends ConsumerWidget {
  const _AccountDetails({required this.account});

  final Account account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final custodian = ref.watch(accountCustodianProvider(account.custodianId));

    final custodianName =
        custodian.value?.valueOrNull?.name ?? account.custodianId.value;

    return ListView(
      children: [
        AppContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  EntityVisual(
                    icon: account.icon,
                    color: account.color,
                    logo: account.logo,
                    size: AppSize.entityVisualLarge,
                  ),
                  const SizedBox(width: AppSpacing.medium),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          account.name,
                          style: theme.textTheme.headlineSmall,
                        ),
                        const SizedBox(height: AppSpacing.xxSmall),
                        Text(
                          _accountKindLabel(account.kind),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Edit account',
                    onPressed: () async {
                      await context.router.push(
                        EditAccountRoute(accountId: account.id.value),
                      );

                      ref.invalidate(accountProvider(account.id));
                      ref.invalidate(
                        accountValuationPresentationProvider(account.id),
                      );
                    },
                    icon: const Icon(Symbols.edit_rounded),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.large),
              AccountBalancePresentation(
                accountId: account.id,
                mode: AccountBalancePresentationMode.detailed,
              ),
              const SizedBox(height: AppSpacing.large),
              _DetailRow(label: 'Custodian', value: custodianName),
              _DetailRow(label: 'Type', value: _accountKindLabel(account.kind)),
              if (account.reference != null)
                _DetailRow(label: 'Reference', value: account.reference!),
              _DetailRow(
                label: 'Status',
                value: account.isArchived ? 'Archived' : 'Active',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

final class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.small),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.medium),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

final class _InvalidAccountPage extends StatelessWidget {
  const _InvalidAccountPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.large),
          child: Text('The account identifier is invalid.'),
        ),
      ),
    );
  }
}

AccountId? _parseAccountId(String value) {
  try {
    return AccountId.fromString(value);
  } on ArgumentError {
    return null;
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
