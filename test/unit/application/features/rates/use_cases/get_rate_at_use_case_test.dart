import 'package:axiom/src/core/failures/referenced_asset_not_found_failure.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/repositories/batch_lookup.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/application/use_cases/get_assets_by_ids_use_case.dart';
import 'package:axiom/src/features/rates/application/services/validate_rate_assets_service.dart';
import 'package:axiom/src/features/rates/application/use_cases/get_rate_at_use_case.dart';
import 'package:axiom/src/features/rates/domain/failures/rate_not_found_failure.dart';
import 'package:axiom/src/features/rates/domain/failures/rate_persistence_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/rates/rate_fixtures.dart';
import '../../../../../fixtures/features/assets/asset_fixtures.dart';
import '../../../../../mocks/asset_repository_mock.dart';
import '../../../../../mocks/rate_repository_mock.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(<AssetId>[]);
  });

  group('GetRateAtUseCase', () {
    late MockAssetRepository assetRepository;
    late MockRateRepository repository;
    late GetRateAtUseCase useCase;
    late AssetId eur;
    late AssetId usd;
    late DateTime at;

    setUp(() {
      assetRepository = MockAssetRepository();
      repository = MockRateRepository();
      useCase = GetRateAtUseCase(
        repository: repository,
        validateRateAssets: ValidateRateAssetsService(
          getAssetsByIds: GetAssetsByIdsUseCase(assetRepository),
        ),
      );
      eur = AssetId.fromString('EUR');
      usd = AssetId.fromString('USD');
      at = DateTime.parse('2026-09-10T14:30:45.123+02:00');

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
    });

    test('returns the repository rate for a successful lookup', () async {
      final rate = exchangeRateFixture(baseAssetId: 'EUR', quoteAssetId: 'USD');
      when(
        () => repository.getAtOrBefore(
          baseAssetId: eur,
          quoteAssetId: usd,
          effectiveAt: at,
        ),
      ).thenAnswer((_) async => Success(rate));

      final result = await useCase(baseAssetId: eur, quoteAssetId: usd, at: at);

      expect(result.valueOrNull, same(rate));
    });

    test('does not return a rate with a missing referenced asset', () async {
      // Given
      final rate = exchangeRateFixture(baseAssetId: 'EUR', quoteAssetId: 'USD');
      when(
        () => repository.getAtOrBefore(
          baseAssetId: eur,
          quoteAssetId: usd,
          effectiveAt: at,
        ),
      ).thenAnswer((_) async => Success(rate));
      when(() => assetRepository.getByIds(any())).thenAnswer(
        (_) async => Success(
          BatchLookup(found: [], missing: [rate.quoteAssetId]),
        ),
      );

      // When
      final result = await useCase(
        baseAssetId: eur,
        quoteAssetId: usd,
        at: at,
      );

      // Then
      expect(result.failureOrNull, isA<ReferencedAssetNotFoundFailure>());
    });

    test('propagates a missing-rate failure unchanged', () async {
      const failure = RateNotFoundFailure(message: 'rate missing');
      when(
        () => repository.getAtOrBefore(
          baseAssetId: eur,
          quoteAssetId: usd,
          effectiveAt: at,
        ),
      ).thenAnswer((_) async => failure);

      final result = await useCase(baseAssetId: eur, quoteAssetId: usd, at: at);

      expect(result.failureOrNull, same(failure));
    });

    test('propagates another repository failure unchanged', () async {
      const failure = RatePersistenceFailure(message: 'storage failure');
      when(
        () => repository.getAtOrBefore(
          baseAssetId: eur,
          quoteAssetId: usd,
          effectiveAt: at,
        ),
      ).thenAnswer((_) async => failure);

      final result = await useCase(baseAssetId: eur, quoteAssetId: usd, at: at);

      expect(result.failureOrNull, same(failure));
    });

    test('forwards the ordered asset pair and exact timestamp once', () async {
      final rate = exchangeRateFixture(baseAssetId: 'EUR', quoteAssetId: 'USD');
      when(
        () => repository.getAtOrBefore(
          baseAssetId: eur,
          quoteAssetId: usd,
          effectiveAt: at,
        ),
      ).thenAnswer((_) async => Success(rate));

      await useCase(baseAssetId: eur, quoteAssetId: usd, at: at);

      verify(
        () => repository.getAtOrBefore(
          baseAssetId: eur,
          quoteAssetId: usd,
          effectiveAt: at,
        ),
      ).called(1);
    });
  });
}
