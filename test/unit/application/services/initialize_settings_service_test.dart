import 'package:axiom/src/application/services/initialize_settings_service.dart';
import 'package:axiom/src/core/failures/record_already_exists_failure.dart';
import 'package:axiom/src/core/failures/record_not_found_failure.dart';
import 'package:axiom/src/core/failures/unexpected_persistence_failure.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/settings/domain/entities/settings.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../fixtures/features/assets/asset_fixtures.dart';
import '../../../mocks/create_settings_use_case_mock.dart';
import '../../../mocks/get_asset_by_id_use_case_mock.dart';

void main() {
  group('InitializeSettingsService', () {
    late MockGetAssetByIdUseCase getAssetById;
    late MockCreateSettingsUseCase createSettings;
    late InitializeSettingsService service;

    setUp(() {
      getAssetById = MockGetAssetByIdUseCase();
      createSettings = MockCreateSettingsUseCase();
      service = InitializeSettingsService(
        getAssetById: getAssetById,
        createSettings: createSettings,
      );
    });

    test('returns created settings for a currency valuation asset', () async {
      // Given
      final valuationAssetId = AssetId.fromString('valuation-currency');
      final currency = currencyFixture(id: valuationAssetId.value);
      final settings = Settings(valuationCurrencyId: valuationAssetId);
      when(
        () => getAssetById(valuationAssetId),
      ).thenAnswer((_) async => Success<Asset?>(currency));
      when(
        () => createSettings(settings),
      ).thenAnswer((_) async => Success<Settings>(settings));

      // When
      final result = await service.call(valuationAssetId: valuationAssetId);

      // Then
      expect(result.valueOrNull, same(settings));
      verify(() => getAssetById(valuationAssetId)).called(1);
      verify(() => createSettings(settings)).called(1);
    });

    test('propagates asset retrieval failures', () async {
      // Given
      final valuationAssetId = AssetId.fromString('missing-lookup');
      const failure = UnexpectedPersistenceFailure(message: 'read failed');
      when(
        () => getAssetById(valuationAssetId),
      ).thenAnswer((_) async => failure);

      // When
      final result = await service.call(valuationAssetId: valuationAssetId);

      // Then
      expect(result.failureOrNull, same(failure));
      verifyNever(() => createSettings(any()));
    });

    test(
      'returns not-found failure when the valuation asset is absent',
      () async {
        // Given
        final valuationAssetId = AssetId.fromString('absent-valuation');
        when(
          () => getAssetById(valuationAssetId),
        ).thenAnswer((_) async => const Success<Asset?>(null));

        // When
        final result = await service.call(valuationAssetId: valuationAssetId);

        // Then
        expect(result.failureOrNull, isA<RecordNotFoundFailure>());
        expect(result.failureOrNull?.message, contains(valuationAssetId.value));
        verifyNever(() => createSettings(any()));
      },
    );

    test('propagates settings creation failures', () async {
      // Given
      final valuationAssetId = AssetId.fromString('duplicate-valuation');
      final currency = currencyFixture(id: valuationAssetId.value);
      final settings = Settings(valuationCurrencyId: valuationAssetId);
      const failure = RecordAlreadyExistsFailure(message: 'settings exist');
      when(
        () => getAssetById(valuationAssetId),
      ).thenAnswer((_) async => Success<Asset?>(currency));
      when(() => createSettings(settings)).thenAnswer((_) async => failure);

      // When
      final result = await service.call(valuationAssetId: valuationAssetId);

      // Then
      expect(result.failureOrNull, same(failure));
      verify(() => createSettings(settings)).called(1);
    });
  });
}
