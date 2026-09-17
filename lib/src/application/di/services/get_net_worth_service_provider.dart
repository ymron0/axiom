import 'package:axiom/src/application/di/services/asset_valuation_service_provider.dart';
import 'package:axiom/src/application/di/services/get_account_balance_service_provider.dart';
import 'package:axiom/src/application/services/get_net_worth_service.dart';
import 'package:axiom/src/core/di/clock_provider.dart';
import 'package:axiom/src/features/accounts/di/get_accounts_use_case_provider.dart';
import 'package:axiom/src/features/settings/di/get_settings_use_case_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'get_net_worth_service_provider.g.dart';

/// Provides the service that derives current net worth.
///
/// Feature-owned access is resolved through feature use cases, while
/// application-level calculations are composed through their application
/// service providers.
///
/// The shared [clockProvider] guarantees that time remains an injected
/// application dependency.
@riverpod
GetNetWorthService getNetWorthService(Ref ref) {
  return GetNetWorthService(
    getSettings: ref.watch(getSettingsUseCaseProvider),
    getAccounts: ref.watch(getAccountsUseCaseProvider),
    getAccountBalance: ref.watch(getAccountBalanceServiceProvider),
    assetValuation: ref.watch(assetValuationServiceProvider),
    clock: ref.watch(clockProvider),
  );
}
