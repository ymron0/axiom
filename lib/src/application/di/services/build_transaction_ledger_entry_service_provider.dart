import 'package:axiom/src/application/di/services/get_valuation_currency_service_provider.dart';
import 'package:axiom/src/application/di/services/value_asset_amounts_service_provider.dart';
import 'package:axiom/src/application/services/build_transaction_ledger_entry_service.dart';
import 'package:axiom/src/features/accounts/di/get_account_by_id_use_case_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'build_transaction_ledger_entry_service_provider.g.dart';

/// Provides conversion-aware transaction ledger-entry construction.
@riverpod
BuildTransactionLedgerEntryService buildTransactionLedgerEntryService(Ref ref) {
  return BuildTransactionLedgerEntryService(
    getAccountById: ref.watch(getAccountByIdUseCaseProvider),
    getValuationCurrency: ref.watch(getValuationCurrencyServiceProvider),
    valueAssetAmounts: ref.watch(valueAssetAmountsServiceProvider),
  );
}