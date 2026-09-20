import 'package:axiom/src/application/di/services/get_account_asset_balances_service_provider.dart';
import 'package:axiom/src/application/di/services/get_valuation_currency_service_provider.dart';
import 'package:axiom/src/application/di/services/value_asset_amounts_service_provider.dart';
import 'package:axiom/src/application/services/get_account_valuation_service.dart';
import 'package:axiom/src/core/di/clock_provider.dart';
import 'package:axiom/src/features/accounts/di/get_account_by_id_use_case_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'get_account_valuation_service_provider.g.dart';

/// Provides current account valuation in the configured valuation Currency.
@riverpod
GetAccountValuationService getAccountValuationService(Ref ref) {
  return GetAccountValuationService(
    getAccountById: ref.watch(getAccountByIdUseCaseProvider),
    getAccountAssetBalances: ref.watch(getAccountAssetBalancesServiceProvider),
    getValuationCurrency: ref.watch(getValuationCurrencyServiceProvider),
    valueAssetAmounts: ref.watch(valueAssetAmountsServiceProvider),
    clock: ref.watch(clockProvider),
  );
}
