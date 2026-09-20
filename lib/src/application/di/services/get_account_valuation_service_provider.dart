import 'package:axiom/src/application/di/services/asset_valuation_service_provider.dart';
import 'package:axiom/src/application/di/services/get_account_balance_service_provider.dart';
import 'package:axiom/src/application/services/get_account_valuation_service.dart';
import 'package:axiom/src/core/di/clock_provider.dart';
import 'package:axiom/src/features/accounts/di/get_account_by_id_use_case_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'get_account_valuation_service_provider.g.dart';

/// Provides current account valuation in the configured Currency.
@riverpod
GetAccountValuationService getAccountValuationService(Ref ref) {
  return GetAccountValuationService(
    getAccountById: ref.watch(getAccountByIdUseCaseProvider),
    getAccountBalance: ref.watch(getAccountBalanceServiceProvider),
    assetValuation: ref.watch(assetValuationServiceProvider),
    clock: ref.watch(clockProvider),
  );
}
