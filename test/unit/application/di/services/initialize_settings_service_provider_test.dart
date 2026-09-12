import 'package:axiom/src/application/di/services/initialize_settings_service_provider.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/di/get_asset_by_id_use_case_provider.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/settings/di/create_settings_use_case_provider.dart';
import 'package:axiom/src/features/settings/domain/entities/settings.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:test/test.dart';

import '../../../../fixtures/features/assets/asset_fixtures.dart';
import '../../../../mocks/create_settings_use_case_mock.dart';
import '../../../../mocks/get_asset_by_id_use_case_mock.dart';

void main() {
  group('initializeSettingsServiceProvider', () {
    test('uses the configured asset lookup and settings creation use cases', () async {
      // Given
      final getAssetById = MockGetAssetByIdUseCase();
      final createSettings = MockCreateSettingsUseCase();
      final valuationAssetId = AssetId.fromString('provider-valuation');
      final currency = currencyFixture(id: valuationAssetId.value);
      final settings = Settings(valuationCurrencyId: valuationAssetId);
      when(
        () => getAssetById(valuationAssetId),
      ).thenAnswer((_) async => Success<Asset?>(currency));
      when(
        () => createSettings(settings),
      ).thenAnswer((_) async => Success<Settings>(settings));
      final container = ProviderContainer(
        overrides: [
          getAssetByIdUseCaseProvider.overrideWithValue(getAssetById),
          createSettingsUseCaseProvider.overrideWithValue(createSettings),
        ],
      );
      addTearDown(container.dispose);

      // When
      final result = await container
          .read(initializeSettingsServiceProvider)
          .call(valuationAssetId: valuationAssetId);

      // Then
      expect(result.valueOrNull, same(settings));
      verify(() => getAssetById(valuationAssetId)).called(1);
      verify(() => createSettings(settings)).called(1);
    });
  });
}
