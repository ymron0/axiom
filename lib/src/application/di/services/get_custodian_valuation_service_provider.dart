import 'package:axiom/src/application/di/services/get_account_valuation_service_provider.dart';
import 'package:axiom/src/application/di/services/get_valuation_currency_service_provider.dart';
import 'package:axiom/src/application/services/get_custodian_valuation_service.dart';
import 'package:axiom/src/features/accounts/di/get_accounts_by_custodian_id_use_case_provider.dart';
import 'package:axiom/src/features/custodians/di/get_custodian_by_id_use_case_provider.dart';
import 'package:axiom/src/features/custodians/domain/services/custodian_aggregation_calculator.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'get_custodian_valuation_service_provider.g.dart';

/// Provides current custodian valuation in the configured Currency.
@riverpod
GetCustodianValuationService getCustodianValuationService(Ref ref) {
  return GetCustodianValuationService(
    getCustodianById: ref.watch(getCustodianByIdUseCaseProvider),
    getAccountsByCustodianId: ref.watch(
      getAccountsByCustodianIdUseCaseProvider,
    ),
    getAccountValuation: ref.watch(getAccountValuationServiceProvider),
    getValuationCurrency: ref.watch(getValuationCurrencyServiceProvider),
    calculator: const CustodianAggregationCalculator(),
  );
}
