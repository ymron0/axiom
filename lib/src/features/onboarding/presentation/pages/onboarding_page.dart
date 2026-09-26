import 'package:axiom/src/core/domain/enums/entity_color.dart';
import 'package:axiom/src/core/domain/enums/entity_icon.dart';
import 'package:axiom/src/core/domain/enums/entity_logo_source.dart';
import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/presentation/failures/mutation_failure_mapper.dart';
import 'package:axiom/src/core/presentation/failures/presentation_failure.dart';
import 'package:axiom/src/core/presentation/tokens/design_tokens.dart';
import 'package:axiom/src/core/presentation/validation/form_validators.dart';
import 'package:axiom/src/core/presentation/widgets/state/async_result_view.dart';
import 'package:axiom/src/features/accounts/domain/entities/account.dart';
import 'package:axiom/src/features/accounts/domain/enums/account_kind.dart';
import 'package:axiom/src/features/accounts/presentation/models/account_form_data.dart';
import 'package:axiom/src/features/accounts/presentation/state/account_mutations.dart';
import 'package:axiom/src/features/accounts/presentation/state/accounts_state.dart';
import 'package:axiom/src/features/accounts/presentation/widgets/account_form.dart';
import 'package:axiom/src/features/custodians/domain/enums/custodian_kind.dart';
import 'package:axiom/src/features/custodians/presentation/models/custodian_form_data.dart';
import 'package:axiom/src/features/custodians/presentation/state/custodian_mutations.dart';
import 'package:axiom/src/features/custodians/presentation/state/custodians_state.dart';
import 'package:axiom/src/features/custodians/presentation/widgets/custodian_form.dart';
import 'package:axiom/src/features/onboarding/presentation/mutations/onboarding_mutations.dart';
import 'package:axiom/src/features/onboarding/presentation/state/onboarding_state.dart';
import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/experimental/mutation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

/// First-run application setup.
///
/// Settings are mandatory. Custodian, account, and initial-balance setup are
/// optional so the user can reach the main application without inventing
/// financial data.
///
/// The valuation currency becomes immutable once the Settings step succeeds.
final class OnboardingPage extends ConsumerWidget {
  /// Creates the onboarding flow.
  const OnboardingPage({super.key});

  static const double _maximumContentWidth = 600;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setup = ref.watch(onboardingSetupDataProvider);
    final flow = ref.watch(onboardingFlowControllerProvider);

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: AsyncResultView<OnboardingSetupData, BaseFailure>(
            value: setup,
            loadingSemanticLabel: 'Loading setup',
            onRetry: () {
              ref.invalidate(onboardingSetupDataProvider);
            },
            builder: (context, setupData) {
              return LayoutBuilder(
                builder: (context, constraints) {
                  return Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: constraints.maxWidth > _maximumContentWidth
                          ? _maximumContentWidth
                          : constraints.maxWidth,
                      child: ListView(
                        padding: const EdgeInsets.all(AppSpacing.medium),
                        children: [
                          _ProgressHeader(step: flow.step),
                          const SizedBox(height: AppSpacing.large),
                          _buildStep(context, ref, flow, setupData),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildStep(
    BuildContext context,
    WidgetRef ref,
    OnboardingFlowState flow,
    OnboardingSetupData setup,
  ) {
    return switch (flow.step) {
      OnboardingStep.welcome => _buildWelcome(context, ref, setup),
      OnboardingStep.valuationCurrency => _buildValuationCurrency(
        context,
        ref,
        flow,
        setup,
      ),
      OnboardingStep.custodian => _buildCustodian(context, ref),
      OnboardingStep.account => _buildAccount(context, ref, flow),
      OnboardingStep.initialBalance => _buildInitialBalance(context, ref, flow),
      OnboardingStep.completion => _buildCompletion(context, ref),
    };
  }

  Widget _buildWelcome(
    BuildContext context,
    WidgetRef ref,
    OnboardingSetupData setup,
  ) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          Symbols.account_balance_wallet_rounded,
          size: 56,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: AppSpacing.large),
        Text(
          setup.settings == null ? 'Set up your finances' : 'Continue setup',
          style: theme.textTheme.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.medium),
        Text(
          setup.settings == null
              ? 'Choose your valuation currency, then optionally add a '
                    'custodian, an account, and its starting balance.'
              : 'Your valuation currency is already configured. Continue '
                    'with the optional account setup steps.',
          style: theme.textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.large),
        const _SetupItem(
          icon: Symbols.currency_exchange_rounded,
          title: 'Valuation currency',
          message: 'Required for financial totals and cross-asset values.',
        ),
        const _SetupItem(
          icon: Symbols.account_balance_rounded,
          title: 'Custodian',
          message: 'Optional bank, broker, wallet, or other institution.',
        ),
        const _SetupItem(
          icon: Symbols.wallet_rounded,
          title: 'Account and balance',
          message: 'Optional account and target starting balance.',
        ),
        const SizedBox(height: AppSpacing.large),
        FilledButton.icon(
          onPressed: () {
            ref
                .read(onboardingFlowControllerProvider.notifier)
                .begin(
                  initializedValuationCurrencyId:
                      setup.settings?.valuationCurrencyId,
                );
          },
          icon: const Icon(Symbols.arrow_forward_rounded),
          label: Text(
            setup.settings == null ? 'Start setup' : 'Continue setup',
          ),
        ),
      ],
    );
  }

  Widget _buildValuationCurrency(
    BuildContext context,
    WidgetRef ref,
    OnboardingFlowState flow,
    OnboardingSetupData setup,
  ) {
    final mutation = ref.watch(initializeOnboardingSettingsMutation);
    final failure = mapMutationFailure(mutation);
    final pending = mutation is MutationPending;

    if (setup.currencies.isEmpty) {
      return EmptyStateView(
        icon: Symbols.currency_exchange_rounded,
        title: 'No currencies available',
        message:
            'At least one currency asset is required before setup can '
            'continue.',
        actionLabel: 'Retry',
        onAction: () {
          ref.invalidate(onboardingSetupDataProvider);
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Choose your valuation currency',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.small),
        Text(
          'Totals, budgets, jars, and cross-asset values use this currency.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.medium),
        _InformationCard(
          icon: Symbols.lock_rounded,
          message:
              'The valuation currency cannot be changed later without '
              'resetting application data.',
        ),
        if (failure != null) ...[
          const SizedBox(height: AppSpacing.medium),
          _InlineFailure(failure: failure),
        ],
        const SizedBox(height: AppSpacing.medium),
        RadioGroup<AssetId>(
          groupValue: flow.valuationCurrencyId,
          onChanged: (value) {
            if (value != null) {
              ref
                  .read(onboardingFlowControllerProvider.notifier)
                  .selectValuationCurrency(value);
            }
          },
          child: Column(
            children: [
              for (final currency in setup.currencies)
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: RadioListTile<AssetId>(
                    value: currency.id,
                    enabled: !pending,
                    title: Text('${currency.code.value} — ${currency.name}'),
                    subtitle: currency.symbol == null
                        ? null
                        : Text(currency.symbol!),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.large),
        FilledButton(
          onPressed: pending || flow.valuationCurrencyId == null
              ? null
              : () async {
                  final currencyId = flow.valuationCurrencyId!;

                  final result = await executeInitializeOnboardingSettings(
                    ref,
                    currencyId,
                  );

                  if (result == null || result.isFailure) {
                    return;
                  }

                  ref
                      .read(onboardingFlowControllerProvider.notifier)
                      .settingsInitialized(currencyId);
                },
          child: pending
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Use this currency'),
        ),
      ],
    );
  }

  Widget _buildCustodian(BuildContext context, WidgetRef ref) {
    final custodians = ref.watch(custodiansProvider);
    final nextSortOrder = ref.watch(nextCustodianSortOrderProvider);

    return AsyncResultView(
      value: custodians,
      onRetry: () {
        ref.invalidate(custodiansProvider);
      },
      builder: (context, existingCustodians) {
        return AsyncResultView(
          value: nextSortOrder,
          onRetry: () {
            ref.invalidate(nextCustodianSortOrderProvider);
          },
          builder: (context, sortOrder) {
            final mutation = ref.watch(createCustodianMutation);
            final failure = mapMutationFailure(mutation);
            final submitting = mutation is MutationPending;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Add a custodian',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.small),
                Text(
                  'A custodian is the bank, broker, wallet provider, '
                  'exchange, or other place holding an account.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (existingCustodians.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.large),
                  _InformationCard(
                    icon: Symbols.check_circle_rounded,
                    message:
                        '${existingCustodians.length} active '
                        '${existingCustodians.length == 1 ? 'custodian' : 'custodians'} '
                        'already available.',
                  ),
                  const SizedBox(height: AppSpacing.medium),
                  FilledButton.tonal(
                    onPressed: submitting
                        ? null
                        : () {
                            ref
                                .read(onboardingFlowControllerProvider.notifier)
                                .custodianReady();
                          },
                    child: const Text('Continue with existing'),
                  ),
                ],
                const SizedBox(height: AppSpacing.large),
                Text(
                  existingCustodians.isEmpty
                      ? 'Create your first custodian'
                      : 'Or create another',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.medium),
                CustodianForm(
                  initialValue: CustodianFormData(
                    name: '',
                    kind: CustodianKind.bank,
                    logoSource: EntityLogoSource.remote,
                    logoValue: null,
                    icon: EntityIcon.accountBalance,
                    color: EntityColor.blue,
                    sortOrder: sortOrder,
                  ),
                  submitLabel: 'Create and continue',
                  failure: failure,
                  submitting: submitting,
                  onSubmit: (data) async {
                    final result = await executeCreateCustodian(ref, data);

                    if (result == null || result.isFailure) {
                      return;
                    }

                    ref
                        .read(onboardingFlowControllerProvider.notifier)
                        .custodianReady();
                  },
                ),
                const SizedBox(height: AppSpacing.medium),
                TextButton(
                  onPressed: submitting
                      ? null
                      : () {
                          ref
                              .read(onboardingFlowControllerProvider.notifier)
                              .skipAccountSetup();
                        },
                  child: const Text('Skip account setup'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildAccount(
    BuildContext context,
    WidgetRef ref,
    OnboardingFlowState flow,
  ) {
    final accounts = ref.watch(accountsProvider);
    final options = ref.watch(accountFormOptionsProvider(null));

    return AsyncResultView(
      value: accounts,
      onRetry: () {
        ref.invalidate(accountsProvider);
      },
      builder: (context, existingAccounts) {
        return AsyncResultView(
          value: options,
          onRetry: () {
            ref.invalidate(accountFormOptionsProvider(null));
          },
          builder: (context, loaded) {
            if (loaded.custodians.isEmpty) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const EmptyStateView(
                    icon: Symbols.account_balance_rounded,
                    title: 'No custodian available',
                    message: 'Create a custodian before creating an account.',
                  ),
                  const SizedBox(height: AppSpacing.medium),
                  FilledButton.tonal(
                    onPressed: () {
                      ref
                          .read(onboardingFlowControllerProvider.notifier)
                          .backToCustodian();
                    },
                    child: const Text('Back to custodian setup'),
                  ),
                  TextButton(
                    onPressed: () {
                      ref
                          .read(onboardingFlowControllerProvider.notifier)
                          .skipAccountSetup();
                    },
                    child: const Text('Skip account setup'),
                  ),
                ],
              );
            }

            if (loaded.assets.isEmpty) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const EmptyStateView(
                    icon: Symbols.currency_exchange_rounded,
                    title: 'No assets available',
                    message:
                        'At least one asset is required to create an account.',
                  ),
                  const SizedBox(height: AppSpacing.medium),
                  TextButton(
                    onPressed: () {
                      ref
                          .read(onboardingFlowControllerProvider.notifier)
                          .skipAccountSetup();
                    },
                    child: const Text('Skip account setup'),
                  ),
                ],
              );
            }

            final mutation = ref.watch(createAccountMutation);
            final failure = mapMutationFailure(mutation);
            final submitting = mutation is MutationPending;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Add an account',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.small),
                Text(
                  'Accounts hold balances in a specific denomination asset.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                if (existingAccounts.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.large),
                  _ExistingAccountSelector(
                    accounts: existingAccounts,
                    disabled: submitting,
                    onContinue: (accountId) {
                      ref
                          .read(onboardingFlowControllerProvider.notifier)
                          .accountReady(accountId);
                    },
                  ),
                  const SizedBox(height: AppSpacing.large),
                  Text(
                    'Or create another',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ] else ...[
                  const SizedBox(height: AppSpacing.large),
                  Text(
                    'Create your first account',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
                const SizedBox(height: AppSpacing.medium),
                AccountForm(
                  custodians: loaded.custodians,
                  assets: loaded.assets,
                  initialValue: AccountFormData(
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
                  ),
                  submitLabel: 'Create and continue',
                  failure: failure,
                  submitting: submitting,
                  onSubmit: (data) async {
                    final result = await executeCreateAccount(ref, data);

                    if (result == null || result.isFailure) {
                      return;
                    }

                    ref
                        .read(onboardingFlowControllerProvider.notifier)
                        .accountReady(result.valueOrNull!.id);
                  },
                ),
                const SizedBox(height: AppSpacing.medium),
                TextButton(
                  onPressed: submitting
                      ? null
                      : () {
                          ref
                              .read(onboardingFlowControllerProvider.notifier)
                              .skipAccountSetup();
                        },
                  child: const Text('Skip account setup'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildInitialBalance(
    BuildContext context,
    WidgetRef ref,
    OnboardingFlowState flow,
  ) {
    final accountId = flow.accountId;

    if (accountId == null) {
      return const EmptyStateView(
        icon: Symbols.error_rounded,
        title: 'No account selected',
        message:
            'An account must be selected before setting an initial balance.',
      );
    }

    final data = ref.watch(onboardingAccountBalanceDataProvider(accountId));

    return AsyncResultView(
      value: data,
      onRetry: () {
        ref.invalidate(onboardingAccountBalanceDataProvider(accountId));
      },
      builder: (context, loaded) {
        final mutation = ref.watch(initializeAccountBalanceMutation);
        final failure = mapMutationFailure(mutation);
        final submitting = mutation is MutationPending;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Set the starting balance',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.small),
            Text(
              loaded.account.name,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.medium),
            _InformationCard(
              icon: Symbols.calculate_rounded,
              message:
                  'Current balance: ${loaded.currentBalance} '
                  '${loaded.denominationAsset.code.value}. '
                  'Only the correction required to reach the target balance '
                  'will be recorded.',
            ),
            const SizedBox(height: AppSpacing.large),
            _InitialBalanceForm(
              initialValue: loaded.currentBalance,
              assetCode: loaded.denominationAsset.code.value,
              submitting: submitting,
              failure: failure,
              onSubmit: (targetBalance) async {
                final result = await executeInitializeAccountBalance(
                  ref,
                  accountId: accountId,
                  targetBalance: targetBalance,
                );

                if (result == null || result.isFailure) {
                  return;
                }

                ref
                    .read(onboardingFlowControllerProvider.notifier)
                    .balanceReady();
              },
            ),
            const SizedBox(height: AppSpacing.medium),
            TextButton(
              onPressed: submitting
                  ? null
                  : () {
                      ref
                          .read(onboardingFlowControllerProvider.notifier)
                          .skipInitialBalance();
                    },
              child: const Text('Skip initial balance'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCompletion(BuildContext context, WidgetRef ref) {
    final mutation = ref.watch(completeOnboardingMutation);
    final failure = mapMutationFailure(mutation);
    final pending = mutation is MutationPending;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          Symbols.check_circle_rounded,
          size: 64,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: AppSpacing.large),
        Text(
          'Setup is ready',
          style: Theme.of(context).textTheme.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppSpacing.medium),
        Text(
          'You can add or edit accounts, custodians, assets, merchants, '
          'categories, jars, and other settings later.',
          style: Theme.of(context).textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
        if (failure != null) ...[
          const SizedBox(height: AppSpacing.large),
          _InlineFailure(failure: failure),
        ],
        const SizedBox(height: AppSpacing.large),
        FilledButton.icon(
          onPressed: pending
              ? null
              : () async {
                  await executeCompleteOnboarding(ref);
                },
          icon: pending
              ? const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Symbols.done_rounded),
          label: const Text('Finish setup'),
        ),
      ],
    );
  }
}

final class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.step});

  final OnboardingStep step;

  @override
  Widget build(BuildContext context) {
    final progress = switch (step) {
      OnboardingStep.welcome => 0.0,
      OnboardingStep.valuationCurrency => 0.2,
      OnboardingStep.custodian => 0.4,
      OnboardingStep.account => 0.6,
      OnboardingStep.initialBalance => 0.8,
      OnboardingStep.completion => 1.0,
    };

    return Semantics(
      label: 'Setup progress ${(progress * 100).round()} percent',
      child: ExcludeSemantics(child: LinearProgressIndicator(value: progress)),
    );
  }
}

final class _SetupItem extends StatelessWidget {
  const _SetupItem({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.small),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon),
          const SizedBox(width: AppSpacing.medium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: AppSpacing.xxSmall),
                Text(message),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

final class _InformationCard extends StatelessWidget {
  const _InformationCard({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.medium),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(width: AppSpacing.small),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

final class _InitialBalanceForm extends StatefulWidget {
  const _InitialBalanceForm({
    required this.initialValue,
    required this.assetCode,
    required this.submitting,
    required this.onSubmit,
    this.failure,
  });

  final Decimal initialValue;
  final String assetCode;
  final bool submitting;
  final ValueChanged<Decimal> onSubmit;
  final PresentationFailure? failure;

  @override
  State<_InitialBalanceForm> createState() => _InitialBalanceFormState();
}

final class _InitialBalanceFormState extends State<_InitialBalanceForm> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();

    _controller = TextEditingController(text: widget.initialValue.toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.failure != null) ...[
            _InlineFailure(failure: widget.failure!),
            const SizedBox(height: AppSpacing.medium),
          ],
          TextFormField(
            controller: _controller,
            enabled: !widget.submitting,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: true,
            ),
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: 'Target balance',
              suffixText: widget.assetCode,
              helperText: 'Negative balances are supported where appropriate.',
            ),
            validator: FormValidators.decimalNumber,
            onFieldSubmitted: (_) {
              _submit();
            },
          ),
          const SizedBox(height: AppSpacing.large),
          FilledButton(
            onPressed: widget.submitting ? null : _submit,
            child: widget.submitting
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Set initial balance'),
          ),
        ],
      ),
    );
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final normalized = _controller.text.trim().replaceAll(',', '.');

    final value = Decimal.parse(normalized);

    widget.onSubmit(value);
  }
}

final class _InlineFailure extends StatelessWidget {
  const _InlineFailure({required this.failure});

  final PresentationFailure failure;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      liveRegion: true,
      label: '${failure.title}. ${failure.message}',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.medium),
          decoration: BoxDecoration(
            color: theme.colorScheme.errorContainer,
            borderRadius: BorderRadius.circular(AppRadius.medium),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Symbols.error_rounded,
                color: theme.colorScheme.onErrorContainer,
              ),
              const SizedBox(width: AppSpacing.small),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      failure.title,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxSmall),
                    Text(
                      failure.message,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

final class _ExistingAccountSelector extends StatefulWidget {
  const _ExistingAccountSelector({
    required this.accounts,
    required this.disabled,
    required this.onContinue,
  });

  final List<Account> accounts;
  final bool disabled;
  final ValueChanged<AccountId> onContinue;

  @override
  State<_ExistingAccountSelector> createState() =>
      _ExistingAccountSelectorState();
}

final class _ExistingAccountSelectorState
    extends State<_ExistingAccountSelector> {
  late AccountId _selectedId;

  @override
  void initState() {
    super.initState();

    _selectedId = widget.accounts.first.id;
  }

  @override
  void didUpdateWidget(covariant _ExistingAccountSelector oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!widget.accounts.any((account) => account.id == _selectedId)) {
      _selectedId = widget.accounts.first.id;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<AccountId>(
          initialValue: _selectedId,
          decoration: const InputDecoration(labelText: 'Existing account'),
          items: [
            for (final account in widget.accounts)
              DropdownMenuItem(
                value: account.id,
                child: Text(account.name, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: widget.disabled
              ? null
              : (value) {
                  if (value != null) {
                    setState(() => _selectedId = value);
                  }
                },
        ),
        const SizedBox(height: AppSpacing.medium),
        FilledButton.tonal(
          onPressed: widget.disabled
              ? null
              : () => widget.onContinue(_selectedId),
          child: const Text('Use existing account'),
        ),
      ],
    );
  }
}
