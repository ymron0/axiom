@Tags(['di'])
library;

import 'package:axiom/src/application/di/services/get_account_valuation_service_provider.dart';
import 'package:axiom/src/application/di/services/get_custodian_valuation_service_provider.dart';
import 'package:axiom/src/application/di/services/get_valuation_currency_service_provider.dart';
import 'package:axiom/src/application/services/asset_valuation_service.dart';
import 'package:axiom/src/application/services/get_account_valuation_service.dart';
import 'package:axiom/src/application/services/get_custodian_valuation_service.dart';
import 'package:axiom/src/application/services/get_valuation_currency_service.dart';
import 'package:axiom/src/application/services/resolve_conversion_rate_service.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/features/accounts/di/get_accounts_by_custodian_id_use_case_provider.dart';
import 'package:axiom/src/features/custodians/di/get_custodian_by_id_use_case_provider.dart';
import 'package:axiom/src/features/assets/application/use_cases/get_asset_by_id_use_case.dart';
import 'package:axiom/src/features/assets/domain/services/asset_valuation_calculator.dart';
import 'package:axiom/src/features/rates/domain/services/rate_conversion_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:test/test.dart';

import '../../../../mocks/asset_repository_mock.dart';
import '../../../../mocks/get_account_balance_service_mock.dart';
import '../../../../mocks/get_account_by_id_use_case_mock.dart';
import '../../../../mocks/get_accounts_by_custodian_id_use_case_mock.dart';
import '../../../../mocks/get_custodian_by_id_use_case_mock.dart';
import '../../../../mocks/get_rate_at_use_case_mock.dart';
import '../../../../mocks/get_settings_use_case_mock.dart';

void main() {
  test('provides a custodian valuation service from its overrides', () {
    final container = ProviderContainer(
      overrides: [
        getCustodianByIdUseCaseProvider.overrideWithValue(
          MockGetCustodianByIdUseCase(),
        ),
        getAccountsByCustodianIdUseCaseProvider.overrideWithValue(
          MockGetAccountsByCustodianIdUseCase(),
        ),
        getAccountValuationServiceProvider.overrideWithValue(
          _accountValuation(),
        ),
        getValuationCurrencyServiceProvider.overrideWithValue(
          _valuationCurrency(),
        ),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(getCustodianValuationServiceProvider),
      isA<GetCustodianValuationService>(),
    );
  });
}

GetValuationCurrencyService _valuationCurrency() {
  return GetValuationCurrencyService(
    getSettings: MockGetSettingsUseCase(),
    getAssetById: GetAssetByIdUseCase(MockAssetRepository()),
  );
}

GetAccountValuationService _accountValuation() {
  return GetAccountValuationService(
    getAccountById: MockGetAccountByIdUseCase(),
    getAccountBalance: MockGetAccountBalanceService(),
    assetValuation: AssetValuationService(
      getValuationCurrency: _valuationCurrency(),
      resolveConversionRate: ResolveConversionRateService(
        getRateAt: MockGetRateAtUseCase(),
        canonicalBridgeAssetId: AssetId.fromString('bridge'),
        rateConversion: const RateConversionService(),
      ),
      calculator: const AssetValuationCalculator(),
    ),
    clock: FixedClock(DateTime.utc(2026, 9, 20)),
  );
}
