import 'package:axiom/src/application/di/services/build_transaction_ledger_entry_service_provider.dart';
import 'package:axiom/src/application/di/services/create_transaction_service_provider.dart';
import 'package:axiom/src/application/di/services/get_account_balance_service_provider.dart';
import 'package:axiom/src/application/services/create_initial_balance_service.dart';
import 'package:axiom/src/core/di/clock_provider.dart';
import 'package:axiom/src/features/accounts/di/get_account_by_id_use_case_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'create_initial_balance_service_provider.g.dart';

/// Provides initial account-balance setup.
@riverpod
CreateInitialBalanceService createInitialBalanceService(Ref ref) {
  return CreateInitialBalanceService(
    getAccountById: ref.watch(getAccountByIdUseCaseProvider),
    getAccountBalance: ref.watch(getAccountBalanceServiceProvider),
    buildLedgerEntry: ref.watch(buildTransactionLedgerEntryServiceProvider),
    createTransaction: ref.watch(createTransactionServiceProvider),
    clock: ref.watch(clockProvider),
  );
}
