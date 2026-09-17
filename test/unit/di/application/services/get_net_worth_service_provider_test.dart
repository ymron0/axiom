@Tags(['di'])
library;

import 'package:axiom/src/application/di/services/asset_valuation_service_provider.dart';
import 'package:axiom/src/application/di/services/get_account_balance_service_provider.dart';
import 'package:axiom/src/application/di/services/get_net_worth_service_provider.dart';
import 'package:axiom/src/application/services/asset_valuation_service.dart';
import 'package:axiom/src/application/services/get_net_worth_service.dart';
import 'package:axiom/src/application/services/resolve_conversion_rate_service.dart';
import 'package:axiom/src/core/di/clock_provider.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/features/accounts/application/use_cases/get_accounts_use_case.dart';
import 'package:axiom/src/features/accounts/di/get_accounts_use_case_provider.dart';
import 'package:axiom/src/features/assets/domain/services/asset_valuation_calculator.dart';
import 'package:axiom/src/features/rates/domain/services/rate_conversion_service.dart';
import 'package:axiom/src/features/settings/application/use_cases/get_settings_use_case.dart';
import 'package:axiom/src/features/settings/di/get_settings_use_case_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:test/test.dart';

import '../../../../mocks/account_repository_mock.dart';
import '../../../../mocks/get_account_balance_service_mock.dart';
import '../../../../mocks/get_rate_at_use_case_mock.dart';
import '../../../../mocks/settings_repository_mock.dart';

void main() {
  group('getNetWorthService provider', () {
    test('resolves the net worth service', () {
      final container = ProviderContainer(
        overrides: [
          getSettingsUseCaseProvider.overrideWithValue(
            GetSettingsUseCase(MockSettingsRepository()),
          ),
          getAccountsUseCaseProvider.overrideWithValue(
            GetAccountsUseCase(MockAccountRepository()),
          ),
          getAccountBalanceServiceProvider.overrideWithValue(
            MockGetAccountBalanceService(),
          ),
          assetValuationServiceProvider.overrideWithValue(
            AssetValuationService(
              getSettings: GetSettingsUseCase(MockSettingsRepository()),
              resolveConversionRate: ResolveConversionRateService(
                getRateAt: MockGetRateAtUseCase(),
                canonicalBridgeAssetId: AssetId.fromString('usd'),
                rateConversion: const RateConversionService(),
              ),
              calculator: const AssetValuationCalculator(),
            ),
          ),
          clockProvider.overrideWithValue(
            FixedClock(DateTime.utc(2026, 9, 17)),
          ),
        ],
      );
      addTearDown(container.dispose);

      final service = container.read(getNetWorthServiceProvider);

      expect(service, isA<GetNetWorthService>());
    });
  });
}
