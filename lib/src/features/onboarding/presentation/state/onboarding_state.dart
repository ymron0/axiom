import 'package:axiom/src/application/di/services/get_account_balance_service_provider.dart';
import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/accounts/di/get_account_by_id_use_case_provider.dart';
import 'package:axiom/src/features/accounts/domain/entities/account.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_not_found_failure.dart';
import 'package:axiom/src/features/assets/di/get_asset_by_id_use_case_provider.dart';
import 'package:axiom/src/features/assets/di/get_asset_use_case_provider.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/assets/domain/failures/asset_not_found_failure.dart';
import 'package:axiom/src/features/onboarding/di/detect_first_run_use_case_provider.dart';
import 'package:axiom/src/features/onboarding/domain/failures/onboarding_failure.dart';
import 'package:axiom/src/features/settings/di/get_settings_use_case_provider.dart';
import 'package:axiom/src/features/settings/domain/entities/settings.dart';
import 'package:decimal/decimal.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'onboarding_state.g.dart';

/// Data required to initialize the onboarding flow.
final class OnboardingSetupData {
  /// Creates onboarding setup data.
  OnboardingSetupData({
    required this.settings,
    required List<Currency> currencies,
    required this.valuationCurrency,
  }) : currencies = List.unmodifiable(currencies);

  /// Existing Settings when onboarding is being resumed after Settings
  /// initialization.
  final Settings? settings;

  /// Fiat currencies eligible to become the valuation currency.
  final List<Currency> currencies;

  /// Existing configured valuation currency.
  ///
  /// This is `null` exactly when [settings] is `null`.
  final Currency? valuationCurrency;
}

/// Data required by the initial-balance step.
final class OnboardingAccountBalanceData {
  /// Creates balance-step data.
  const OnboardingAccountBalanceData({
    required this.account,
    required this.denominationAsset,
    required this.currentBalance,
  });

  /// Account being initialized.
  final Account account;

  /// Account denomination asset.
  final Asset denominationAsset;

  /// Current signed account balance.
  final Decimal currentBalance;
}

/// Determines whether the root presentation should show onboarding.
@riverpod
Future<Result<bool, OnboardingFailure>> firstRunDetection(Ref ref) {
  return ref.watch(detectFirstRunUseCaseProvider)();
}

/// Loads initial onboarding reference state.
///
/// Only concrete [Currency] assets are exposed as valuation-currency choices.
@riverpod
Future<Result<OnboardingSetupData, BaseFailure>> onboardingSetupData(
  Ref ref,
) async {
  final settingsResult = await ref.watch(getSettingsUseCaseProvider)();

  if (settingsResult case final Failure<BaseFailure> failure) {
    return failure;
  }

  final assetsResult = await ref.watch(getAssetUseCaseProvider)();

  if (assetsResult case final Failure<BaseFailure> failure) {
    return failure;
  }

  final currencies = assetsResult.valueOrNull!.whereType<Currency>().toList(
    growable: false,
  )..sort((left, right) => left.code.value.compareTo(right.code.value));

  final settings = settingsResult.valueOrNull;

  if (settings == null) {
    return Success(
      OnboardingSetupData(
        settings: null,
        currencies: currencies,
        valuationCurrency: null,
      ),
    );
  }

  Currency? valuationCurrency;

  for (final currency in currencies) {
    if (currency.id == settings.valuationCurrencyId) {
      valuationCurrency = currency;
      break;
    }
  }

  if (valuationCurrency == null) {
    return AssetNotFoundFailure(
      message:
          'Configured valuation currency was not found: '
          '${settings.valuationCurrencyId.value}',
    );
  }

  return Success(
    OnboardingSetupData(
      settings: settings,
      currencies: currencies,
      valuationCurrency: valuationCurrency,
    ),
  );
}

/// Loads the account information used by the initial-balance step.
@riverpod
Future<Result<OnboardingAccountBalanceData, BaseFailure>>
onboardingAccountBalanceData(Ref ref, AccountId accountId) async {
  final accountResult = await ref.watch(getAccountByIdUseCaseProvider)(
    accountId,
  );

  if (accountResult case final Failure<BaseFailure> failure) {
    return failure;
  }

  final account = accountResult.valueOrNull;

  if (account == null) {
    return AccountNotFoundFailure(
      message: 'Account ID was not found: ${accountId.value}',
    );
  }

  final assetResult = await ref.watch(getAssetByIdUseCaseProvider)(
    account.denominationAssetId,
  );

  if (assetResult case final Failure<BaseFailure> failure) {
    return failure;
  }

  final asset = assetResult.valueOrNull;

  if (asset == null) {
    return AssetNotFoundFailure(
      message:
          'Account denomination asset was not found: '
          '${account.denominationAssetId.value}',
    );
  }

  final balanceResult = await ref.watch(getAccountBalanceServiceProvider)(
    accountId,
  );

  if (balanceResult case final Failure<BaseFailure> failure) {
    return failure;
  }

  return Success(
    OnboardingAccountBalanceData(
      account: account,
      denominationAsset: asset,
      currentBalance: balanceResult.valueOrNull!,
    ),
  );
}

/// Ordered steps of the first-run experience.
enum OnboardingStep {
  welcome,
  valuationCurrency,
  custodian,
  account,
  initialBalance,
  completion,
}

/// User-controlled onboarding navigation state.
final class OnboardingFlowState {
  /// Creates flow state.
  const OnboardingFlowState({
    required this.step,
    required this.valuationCurrencyId,
    required this.accountId,
  });

  /// Creates the initial flow state.
  const OnboardingFlowState.initial()
    : step = OnboardingStep.welcome,
      valuationCurrencyId = null,
      accountId = null;

  /// Current onboarding step.
  final OnboardingStep step;

  /// Selected or already initialized valuation currency.
  final AssetId? valuationCurrencyId;

  /// Account selected or created for initial-balance setup.
  final AccountId? accountId;

  /// Creates a changed copy.
  OnboardingFlowState copyWith({
    OnboardingStep? step,
    AssetId? valuationCurrencyId,
    AccountId? accountId,
    bool clearAccountId = false,
  }) {
    return OnboardingFlowState(
      step: step ?? this.step,
      valuationCurrencyId: valuationCurrencyId ?? this.valuationCurrencyId,
      accountId: clearAccountId ? null : accountId ?? this.accountId,
    );
  }
}

/// Owns local navigation and selection state for onboarding.
@riverpod
class OnboardingFlowController extends _$OnboardingFlowController {
  @override
  OnboardingFlowState build() {
    return const OnboardingFlowState.initial();
  }

  /// Starts or resumes onboarding.
  void begin({AssetId? initializedValuationCurrencyId}) {
    state = OnboardingFlowState(
      step: initializedValuationCurrencyId == null
          ? OnboardingStep.valuationCurrency
          : OnboardingStep.custodian,
      valuationCurrencyId: initializedValuationCurrencyId,
      accountId: null,
    );
  }

  /// Selects a valuation currency without persisting it yet.
  void selectValuationCurrency(AssetId value) {
    state = state.copyWith(valuationCurrencyId: value);
  }

  /// Advances after Settings have been initialized.
  void settingsInitialized(AssetId valuationCurrencyId) {
    state = state.copyWith(
      step: OnboardingStep.custodian,
      valuationCurrencyId: valuationCurrencyId,
    );
  }

  /// Advances after choosing or creating a custodian.
  void custodianReady() {
    state = state.copyWith(step: OnboardingStep.account);
  }

  /// Returns from account setup to custodian setup.
  void backToCustodian() {
    state = state.copyWith(
      step: OnboardingStep.custodian,
      clearAccountId: true,
    );
  }

  /// Advances after choosing or creating an account.
  void accountReady(AccountId accountId) {
    state = state.copyWith(
      step: OnboardingStep.initialBalance,
      accountId: accountId,
    );
  }

  /// Skips optional account creation and initial balance.
  void skipAccountSetup() {
    state = state.copyWith(
      step: OnboardingStep.completion,
      clearAccountId: true,
    );
  }

  /// Advances after initial-balance setup.
  void balanceReady() {
    state = state.copyWith(step: OnboardingStep.completion);
  }

  /// Skips initial-balance creation.
  void skipInitialBalance() {
    state = state.copyWith(step: OnboardingStep.completion);
  }
}
