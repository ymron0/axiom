import 'package:axiom/src/application/di/services/create_initial_balance_service_provider.dart';
import 'package:axiom/src/application/di/services/ensure_initial_settings_service_provider.dart';
import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/accounts/presentation/state/accounts_state.dart';
import 'package:axiom/src/features/onboarding/di/complete_onboarding_use_case_provider.dart';
import 'package:axiom/src/features/onboarding/domain/entities/onboarding_status.dart';
import 'package:axiom/src/features/onboarding/domain/failures/onboarding_failure.dart';
import 'package:axiom/src/features/onboarding/presentation/state/onboarding_state.dart';
import 'package:axiom/src/features/settings/domain/entities/settings.dart';
import 'package:axiom/src/features/settings/presentation/state/settings_state.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/experimental/mutation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks initial Settings creation.
final initializeOnboardingSettingsMutation =
    Mutation<Result<Settings, BaseFailure>>(
      label: 'initialize-onboarding-settings',
    );

/// Tracks initial account-balance creation.
final initializeAccountBalanceMutation =
    Mutation<Result<Transaction?, BaseFailure>>(
      label: 'initialize-account-balance',
    );

/// Tracks final onboarding completion.
final completeOnboardingMutation =
    Mutation<Result<OnboardingStatus, OnboardingFailure>>(
      label: 'complete-onboarding',
    );

/// Initializes Settings for onboarding.
Future<Result<Settings, BaseFailure>?> executeInitializeOnboardingSettings(
  WidgetRef ref,
  AssetId valuationCurrencyId,
) async {
  try {
    final result = await initializeOnboardingSettingsMutation.run(ref, (
      transaction,
    ) {
      final service = transaction.get(ensureInitialSettingsServiceProvider);

      return service(valuationCurrencyId: valuationCurrencyId);
    });

    if (result.isSuccess) {
      ref
        ..invalidate(onboardingSetupDataProvider)
        ..invalidate(settingsScreenDataProvider);
    }

    return result;
  } on Object {
    return null;
  }
}

/// Sets an account's target initial balance.
Future<Result<Transaction?, BaseFailure>?> executeInitializeAccountBalance(
  WidgetRef ref, {
  required AccountId accountId,
  required Decimal targetBalance,
}) async {
  try {
    final result = await initializeAccountBalanceMutation.run(ref, (
      transaction,
    ) {
      final service = transaction.get(createInitialBalanceServiceProvider);

      return service(accountId: accountId, targetBalance: targetBalance);
    });

    if (result.isSuccess) {
      ref
        ..invalidate(onboardingAccountBalanceDataProvider(accountId))
        ..invalidate(accountValuationPresentationProvider(accountId));
    }

    return result;
  } on Object {
    return null;
  }
}

/// Persists onboarding completion.
Future<Result<OnboardingStatus, OnboardingFailure>?> executeCompleteOnboarding(
  WidgetRef ref,
) async {
  try {
    final result = await completeOnboardingMutation.run(ref, (transaction) {
      return transaction.get(completeOnboardingUseCaseProvider)();
    });

    if (result.isSuccess) {
      ref.invalidate(firstRunDetectionProvider);
    }

    return result;
  } on Object {
    return null;
  }
}
