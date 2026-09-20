@Tags(['di'])
library;

import 'package:axiom/src/application/di/services/asset_valuation_service_provider.dart';
import 'package:axiom/src/application/di/services/resolve_conversion_rate_service_provider.dart';
import 'package:axiom/src/application/services/asset_valuation_service.dart';
import 'package:axiom/src/application/services/resolve_conversion_rate_service.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/features/rates/domain/services/rate_conversion_service.dart';
import 'package:axiom/src/features/settings/application/use_cases/get_settings_use_case.dart';
import 'package:axiom/src/features/settings/di/get_settings_use_case_provider.dart';
import 'package:axiom/src/features/assets/di/get_asset_by_id_use_case_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:test/test.dart';

import '../../../../mocks/get_rate_at_use_case_mock.dart';
import '../../../../mocks/settings_repository_mock.dart';
import '../../../../mocks/get_asset_by_id_use_case_mock.dart';

void main() {
  group('assetValuationService provider', () {
    test('resolves the asset valuation service', () {
      final container = ProviderContainer(
        overrides: [
          getAssetByIdUseCaseProvider.overrideWithValue(
            MockGetAssetByIdUseCase(),
          ),
          getSettingsUseCaseProvider.overrideWithValue(
            GetSettingsUseCase(MockSettingsRepository()),
          ),
          resolveConversionRateServiceProvider.overrideWithValue(
            ResolveConversionRateService(
              getRateAt: MockGetRateAtUseCase(),
              canonicalBridgeAssetId: AssetId.fromString('usd'),
              rateConversion: const RateConversionService(),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final service = container.read(assetValuationServiceProvider);

      expect(service, isA<AssetValuationService>());
    });
  });
}
