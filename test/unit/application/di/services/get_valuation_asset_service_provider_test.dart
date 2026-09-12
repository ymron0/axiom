import 'package:axiom/src/application/di/services/get_valuation_asset_service_provider.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/di/get_asset_by_id_use_case_provider.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/settings/di/get_settings_use_case_provider.dart';
import 'package:axiom/src/features/settings/domain/entities/settings.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:test/test.dart';

import '../../../../fixtures/features/assets/asset_fixtures.dart';
import '../../../../mocks/get_asset_by_id_use_case_mock.dart';
import '../../../../mocks/get_settings_use_case_mock.dart';


void main() {
  group('getValuationAssetServiceProvider', () {
    test('uses the configured settings and asset use cases', () async {
      // Given
      final getSettings = MockGetSettingsUseCase();
      final getAssetById = MockGetAssetByIdUseCase();
      final assetId = AssetId.fromString('provider-valuation');
      final asset = currencyFixture(id: assetId.value);
      final settings = Settings(valuationCurrencyId: assetId);
      when(() => getSettings()).thenAnswer((_) async => Success(settings));
      when(
        () => getAssetById(assetId),
      ).thenAnswer((_) async => Success<Asset?>(asset));
      final container = ProviderContainer(
        overrides: [
          getSettingsUseCaseProvider.overrideWithValue(getSettings),
          getAssetByIdUseCaseProvider.overrideWithValue(getAssetById),
        ],
      );
      addTearDown(container.dispose);

      // When
      final result = await container
          .read(getValuationAssetServiceProvider)
          .call();

      // Then
      expect(result.valueOrNull, same(asset));
      verify(() => getSettings()).called(1);
      verify(() => getAssetById(assetId)).called(1);
    });
  });
}
