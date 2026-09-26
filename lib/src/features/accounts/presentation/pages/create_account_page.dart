import 'package:auto_route/auto_route.dart';
import 'package:axiom/src/core/domain/enums/entity_color.dart';
import 'package:axiom/src/core/domain/enums/entity_icon.dart';
import 'package:axiom/src/core/domain/enums/entity_logo_source.dart';
import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/presentation/failures/mutation_failure_mapper.dart';
import 'package:axiom/src/core/presentation/navigation/app_router.gr.dart';
import 'package:axiom/src/core/presentation/widgets/content/app_content.dart';
import 'package:axiom/src/core/presentation/widgets/state/async_result_view.dart';
import 'package:axiom/src/features/accounts/domain/enums/account_kind.dart';
import 'package:axiom/src/features/accounts/presentation/models/account_form_data.dart';
import 'package:axiom/src/features/accounts/presentation/state/account_mutations.dart';
import 'package:axiom/src/features/accounts/presentation/state/accounts_state.dart';
import 'package:axiom/src/features/accounts/presentation/widgets/account_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/experimental/mutation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Creates a new account.
@RoutePage()
final class CreateAccountPage extends ConsumerWidget {
  /// Creates the page.
  const CreateAccountPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = ref.watch(accountFormOptionsProvider(null));

    final mutationState = ref.watch(createAccountMutation);
    final failure = mapMutationFailure(mutationState);
    final submitting = mutationState is MutationPending;

    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: AsyncResultView<AccountFormOptions, BaseFailure>(
        value: options,
        onRetry: () {
          ref.invalidate(accountFormOptionsProvider(null));
        },
        loadingSemanticLabel: 'Loading account form',
        builder: (context, loaded) {
          if (loaded.custodians.isEmpty) {
            return EmptyStateView(
              icon: Symbols.account_balance_rounded,
              title: 'Create a custodian first',
              message:
                  'Every account belongs to a bank, broker, wallet, '
                  'or another custodian.',
              actionLabel: 'Create custodian',
              onAction: () {
                context.router.push(const CreateCustodianRoute());
              },
            );
          }

          if (loaded.assets.isEmpty) {
            return const EmptyStateView(
              icon: Symbols.currency_exchange_rounded,
              title: 'No assets available',
              message:
                  'At least one asset must exist before an account can '
                  'be created.',
            );
          }

          final initial = AccountFormData(
            name: '',
            custodianId: loaded.custodians.first.id,
            denominationAssetId: loaded.assets.first.id,
            kind: AccountKind.checking,
            reference: null,
            logoSource: EntityLogoSource.remote,
            logoValue: null,
            icon: EntityIcon.accountBalanceWallet,
            color: EntityColor.blue,
            sortOrder: loaded.nextSortOrder,
          );

          return SingleChildScrollView(
            child: AppContent(
              child: AccountForm(
                custodians: loaded.custodians,
                assets: loaded.assets,
                initialValue: initial,
                submitLabel: 'Create account',
                failure: failure,
                submitting: submitting,
                onSubmit: (data) async {
                  final result = await executeCreateAccount(ref, data);

                  if (!context.mounted || result == null || result.isFailure) {
                    return;
                  }

                  final created = result.valueOrNull!;

                  context.router.replace(
                    AccountDetailsRoute(accountId: created.id.value),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
