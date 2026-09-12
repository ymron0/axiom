import 'package:axiom/src/features/assets/application/services/get_valuation_asset_service.dart';
import 'package:axiom/src/core/failures/record_not_found_failure.dart';
import 'package:axiom/src/core/failures/unexpected_persistence_failure.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/settings/domain/entities/settings.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../fixtures/features/assets/asset_fixtures.dart';
import '../../../mocks/get_asset_by_id_use_case_mock.dart';
import '../../../mocks/get_settings_use_case_mock.dart';

void main() {
  group('GetValuationAssetService', () {
    late MockGetAssetByIdUseCase getAssetById;
    late MockGetSettingsUseCase getSettings;
    late GetValuationAssetService service;

    setUp(() {
      getAssetById = MockGetAssetByIdUseCase();
      getSettings = MockGetSettingsUseCase();
      service = GetValuationAssetService(
        getSettings: getSettings,
        getAssetById: getAssetById,
      );
    });

    test('returns the configured valuation asset', () async {
      // Given
      final assetId = AssetId.fromString('valuation-currency');
      final asset = currencyFixture(id: assetId.value);
      final settings = Settings(valuationCurrencyId: assetId);
      when(() => getSettings()).thenAnswer((_) async => Success(settings));
      when(
        () => getAssetById(assetId),
      ).thenAnswer((_) async => Success<Asset?>(asset));

      // When
      final result = await service.call();

      // Then
      expect(result.valueOrNull, same(asset));
      verify(() => getSettings()).called(1);
      verify(() => getAssetById(assetId)).called(1);
    });

    test('returns not-found when settings are not initialized', () async {
      // Given
      when(
        () => getSettings(),
      ).thenAnswer((_) async => const Success<Settings?>(null));

      // When
      final result = await service.call();

      // Then
      expect(result.failureOrNull, isA<RecordNotFoundFailure>());
      expect(
        result.failureOrNull?.message,
        'Settings have not been initialized.',
      );
      verifyZeroInteractions(getAssetById);
    });

    test('returns not-found when the configured asset is absent', () async {
      // Given
      final assetId = AssetId.fromString('missing-valuation');
      final settings = Settings(valuationCurrencyId: assetId);
      when(() => getSettings()).thenAnswer((_) async => Success(settings));
      when(
        () => getAssetById(assetId),
      ).thenAnswer((_) async => const Success<Asset?>(null));

      // When
      final result = await service.call();

      // Then
      expect(result.failureOrNull, isA<RecordNotFoundFailure>());
      expect(result.failureOrNull?.message, contains(assetId.value));
    });

    test('propagates settings retrieval failures', () async {
      // Given
      const failure = UnexpectedPersistenceFailure(message: 'read failed');
      when(() => getSettings()).thenAnswer((_) async => failure);

      // When
      final result = await service.call();

      // Then
      expect(result.failureOrNull, same(failure));
      verifyZeroInteractions(getAssetById);
    });

    test('propagates asset retrieval failures', () async {
      // Given
      final assetId = AssetId.fromString('unreadable-valuation');
      final settings = Settings(valuationCurrencyId: assetId);
      const failure = UnexpectedPersistenceFailure(message: 'read failed');
      when(() => getSettings()).thenAnswer((_) async => Success(settings));
      when(() => getAssetById(assetId)).thenAnswer((_) async => failure);

      // When
      final result = await service.call();

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
