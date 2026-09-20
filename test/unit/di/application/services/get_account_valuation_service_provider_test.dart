@Tags(['di'])
library;

import 'package:axiom/src/application/di/services/asset_valuation_service_provider.dart';
import 'package:axiom/src/application/di/services/get_account_valuation_service_provider.dart';
import 'package:axiom/src/application/services/asset_valuation_service.dart';
import 'package:axiom/src/application/services/get_account_valuation_service.dart';
import 'package:axiom/src/application/services/resolve_conversion_rate_service.dart';
import 'package:axiom/src/core/di/clock_provider.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/features/accounts/di/get_account_by_id_use_case_provider.dart';
import 'package:axiom/src/features/assets/domain/services/asset_valuation_calculator.dart';
import 'package:axiom/src/features/assets/application/use_cases/get_asset_by_id_use_case.dart';
import 'package:axiom/src/application/services/get_valuation_currency_service.dart';
import 'package:axiom/src/features/rates/domain/services/rate_conversion_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:test/test.dart';

import '../../../../mocks/get_account_balance_service_mock.dart';
import '../../../../mocks/get_account_by_id_use_case_mock.dart';
import '../../../../mocks/get_rate_at_use_case_mock.dart';
import '../../../../mocks/get_settings_use_case_mock.dart';
import '../../../../mocks/asset_repository_mock.dart';
import 'package:axiom/src/application/di/services/get_account_balance_service_provider.dart';

void main() {
  test('provides an account valuation service from its overrides', () {
    final container = ProviderContainer(
      overrides: [
        getAccountByIdUseCaseProvider.overrideWithValue(
          MockGetAccountByIdUseCase(),
        ),
        getAccountBalanceServiceProvider.overrideWithValue(
          MockGetAccountBalanceService(),
        ),
        assetValuationServiceProvider.overrideWithValue(_assetValuation()),
        clockProvider.overrideWithValue(FixedClock(DateTime.utc(2026, 9, 20))),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(getAccountValuationServiceProvider),
      isA<GetAccountValuationService>(),
    );
  });
}

AssetValuationService _assetValuation() {
  return AssetValuationService(
    getValuationCurrency: GetValuationCurrencyService(
      getSettings: MockGetSettingsUseCase(),
      getAssetById: GetAssetByIdUseCase(MockAssetRepository()),
    ),
    resolveConversionRate: ResolveConversionRateService(
      getRateAt: MockGetRateAtUseCase(),
      canonicalBridgeAssetId: AssetId.fromString('bridge'),
      rateConversion: const RateConversionService(),
    ),
    calculator: const AssetValuationCalculator(),
  );
}
