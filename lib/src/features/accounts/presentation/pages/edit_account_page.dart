import 'package:auto_route/auto_route.dart';
import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/presentation/failures/mutation_failure_mapper.dart';
import 'package:axiom/src/core/presentation/widgets/content/app_content.dart';
import 'package:axiom/src/core/presentation/widgets/state/async_result_view.dart';
import 'package:axiom/src/features/accounts/domain/entities/account.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_failure.dart';
import 'package:axiom/src/features/accounts/presentation/models/account_form_data.dart';
import 'package:axiom/src/features/accounts/presentation/state/account_mutations.dart';
import 'package:axiom/src/features/accounts/presentation/state/accounts_state.dart';
import 'package:axiom/src/features/accounts/presentation/widgets/account_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/experimental/mutation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Edits an existing account.
@RoutePage()
final class EditAccountPage extends ConsumerWidget {
  /// Creates the page.
  const EditAccountPage({
    @PathParam('accountId') required this.accountId,
    super.key,
  });

  final String accountId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parsedId = _parseAccountId(accountId);

    if (parsedId == null) {
      return const _InvalidAccountEditPage();
    }

    final accountValue = ref.watch(accountProvider(parsedId));

    return Scaffold(
      appBar: AppBar(title: const Text('Edit account')),
      body: AsyncResultView<Account?, AccountFailure>(
        value: accountValue,
        isEmpty: (account) => account == null,
        emptyTitle: 'Account not found',
        emptyMessage: 'This account can no longer be edited.',
        onRetry: () {
          ref.invalidate(accountProvider(parsedId));
        },
        builder: (context, account) {
          if (account == null) {
            return const SizedBox.shrink();
          }

          return _LoadedEditAccount(account: account);
        },
      ),
    );
  }
}

final class _LoadedEditAccount extends ConsumerWidget {
  const _LoadedEditAccount({required this.account});

  final Account account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final options = ref.watch(accountFormOptionsProvider(account.custodianId));

    final mutationState = ref.watch(updateAccountMutation);
    final failure = mapMutationFailure(mutationState);
    final submitting = mutationState is MutationPending;

    return AsyncResultView<AccountFormOptions, BaseFailure>(
      value: options,
      onRetry: () {
        ref.invalidate(accountFormOptionsProvider(account.custodianId));
      },
      builder: (context, loaded) {
        return SingleChildScrollView(
          child: AppContent(
            child: AccountForm(
              custodians: loaded.custodians,
              assets: loaded.assets,
              initialValue: AccountFormData.fromAccount(account),
              submitLabel: 'Save changes',
              failure: failure,
              submitting: submitting,
              onSubmit: (data) async {
                final result = await executeUpdateAccount(
                  ref,
                  original: account,
                  data: data,
                );

                if (!context.mounted || result == null || result.isFailure) {
                  return;
                }

                context.router.pop();
              },
            ),
          ),
        );
      },
    );
  }
}

final class _InvalidAccountEditPage extends StatelessWidget {
  const _InvalidAccountEditPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit account')),
      body: const Center(child: Text('The account identifier is invalid.')),
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
