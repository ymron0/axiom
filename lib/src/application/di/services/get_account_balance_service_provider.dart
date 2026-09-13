import 'package:axiom/src/application/services/get_account_balance_service.dart';
import 'package:axiom/src/features/accounts/di/get_account_by_id_use_case_provider.dart';
import 'package:axiom/src/features/accounts/domain/services/account_balance_calculator.dart';
import 'package:axiom/src/features/transactions/di/get_ledger_entries_by_account_id_use_case_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'get_account_balance_service_provider.g.dart';

/// Provides the service that derives an account balance.
@riverpod
GetAccountBalanceService getAccountBalanceService(Ref ref) {
  return GetAccountBalanceService(
    getAccountById: ref.watch(getAccountByIdUseCaseProvider),
    getLedgerEntriesByAccountId: ref.watch(
      getLedgerEntriesByAccountIdUseCaseProvider,
    ),
    calculator: const AccountBalanceCalculator(),
  );
}
