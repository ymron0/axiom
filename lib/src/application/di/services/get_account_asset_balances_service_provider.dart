import 'package:axiom/src/application/services/get_account_asset_balances_service.dart';
import 'package:axiom/src/core/di/clock_provider.dart';
import 'package:axiom/src/features/accounts/di/get_account_by_id_use_case_provider.dart';
import 'package:axiom/src/features/accounts/domain/services/account_asset_balance_calculator.dart';
import 'package:axiom/src/features/transactions/di/get_transactions_by_account_id_use_case_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'get_account_asset_balances_service_provider.g.dart';

/// Provides current per-asset account balances.
@riverpod
GetAccountAssetBalancesService getAccountAssetBalancesService(Ref ref) {
  return GetAccountAssetBalancesService(
    getAccountById: ref.watch(getAccountByIdUseCaseProvider),
    getTransactionsByAccountId: ref.watch(
      getTransactionsByAccountIdUseCaseProvider,
    ),
    calculator: const AccountAssetBalanceCalculator(),
    clock: ref.watch(clockProvider),
  );
}
