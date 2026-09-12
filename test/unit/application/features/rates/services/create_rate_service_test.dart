import 'package:axiom/src/core/failures/record_not_found_failure.dart';
import 'package:axiom/src/core/failures/unexpected_persistence_failure.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/repositories/batch_lookup.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/application/failures/invalid_valuation_currency_failure.dart';
import 'package:axiom/src/features/assets/application/use_cases/get_assets_by_ids_use_case.dart';
import 'package:axiom/src/features/rates/application/services/create_rate_service.dart';
import 'package:axiom/src/features/rates/application/services/validate_rate_assets_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/assets/asset_fixtures.dart';
import '../../../../../fixtures/features/rates/rate_fixtures.dart';
import '../../../../../mocks/asset_repository_mock.dart';
import '../../../../../mocks/rate_repository_mock.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(<AssetId>[]);
  });

  group('CreateRateService', () {
    late MockAssetRepository assetRepository;
    late MockRateRepository rateRepository;
    late CreateRateService service;

    setUp(() {
      assetRepository = MockAssetRepository();
      rateRepository = MockRateRepository();
      service = CreateRateService(
        repository: rateRepository,
        validateRateAssets: ValidateRateAssetsService(
          getAssetsByIds: GetAssetsByIdsUseCase(assetRepository),
        ),
        canonicalBridgeAssetId: AssetId.fromString('USD'),
      );
    });

    test('returns the created rate after validation and persistence', () async {
      // Given
      final rate = exchangeRateFixture();
      when(() => assetRepository.getByIds(any())).thenAnswer(
        (_) async => Success(
          BatchLookup(
            found: [
              currencyFixture(id: 'EUR', code: 'EUR'),
              currencyFixture(id: 'USD', code: 'USD'),
            ],
            missing: [],
          ),
        ),
      );
      when(
        () => rateRepository.create(rate),
      ).thenAnswer((_) async => const Success(null));

      // When
      final result = await service(rate);

      // Then
      expect(result.valueOrNull, same(rate));
      verify(() => rateRepository.create(rate)).called(1);
    });

    test('does not persist a rate with a missing referenced asset', () async {
      // Given
      final rate = exchangeRateFixture();
      when(() => assetRepository.getByIds(any())).thenAnswer(
        (_) async =>
            Success(BatchLookup(found: [], missing: [rate.baseAssetId])),
      );

      // When
      final result = await service(rate);

      // Then
      expect(result.failureOrNull, isA<RecordNotFoundFailure>());
      verifyNever(() => rateRepository.create(rate));
    });

    test('does not persist a rate quoted in a non-USD asset', () async {
      // Given
      final rate = exchangeRateFixture(baseAssetId: 'CHF', quoteAssetId: 'EUR');

      // When
      final result = await service(rate);

      // Then
      expect(result.failureOrNull, isA<InvalidValuationCurrencyFailure>());
      verifyNever(() => rateRepository.create(rate));
    });

    test('propagates repository failures unchanged', () async {
      // Given
      final rate = exchangeRateFixture();
      const failure = UnexpectedPersistenceFailure(message: 'write failed');
      when(() => assetRepository.getByIds(any())).thenAnswer(
        (_) async => Success(
          BatchLookup(
            found: [
              currencyFixture(id: 'EUR', code: 'EUR'),
              currencyFixture(id: 'USD', code: 'USD'),
            ],
            missing: [],
          ),
        ),
      );
      when(() => rateRepository.create(rate)).thenAnswer((_) async => failure);

      // When
      final result = await service(rate);

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
