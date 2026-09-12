import 'package:axiom/src/core/failures/referenced_asset_not_found_failure.dart';
import 'package:axiom/src/core/failures/record_not_found_failure.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/repositories/batch_lookup.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/application/use_cases/get_asset_by_code_use_case.dart';
import 'package:axiom/src/features/assets/application/use_cases/get_assets_by_ids_use_case.dart';
import 'package:axiom/src/features/assets/domain/failures/asset_not_found_failure.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_code.dart';
import 'package:axiom/src/features/rates/application/services/validate_rate_assets_service.dart';
import 'package:axiom/src/features/rates/application/failures/unsupported_persisted_rate_quote_failure.dart';
import 'package:axiom/src/features/rates/application/use_cases/get_rate_for_pair_use_case.dart';
import 'package:axiom/src/features/rates/domain/failures/rate_not_found_failure.dart';
import 'package:axiom/src/features/rates/domain/failures/rate_persistence_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/assets/asset_fixtures.dart';
import '../../../../../fixtures/features/rates/rate_fixtures.dart';
import '../../../../../mocks/asset_repository_mock.dart';
import '../../../../../mocks/rate_repository_mock.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(AssetCode('USD'));
    registerFallbackValue(AssetId.fromString('fallback'));
    registerFallbackValue(<AssetId>[]);
  });

  group('GetRateForPairUseCase', () {
    late MockAssetRepository assetRepository;
    late MockRateRepository rateRepository;
    late GetRateForPairUseCase useCase;
    late AssetId usd;
    late AssetId chf;

    setUp(() {
      assetRepository = MockAssetRepository();
      rateRepository = MockRateRepository();
      useCase = GetRateForPairUseCase(
        repository: rateRepository,
        getAssetByCode: GetAssetByCodeUseCase(assetRepository),
        validateRateAssets: ValidateRateAssetsService(
          getAssetsByIds: GetAssetsByIdsUseCase(assetRepository),
        ),
      );
      usd = AssetId.fromString('USD');
      chf = AssetId.fromString('CHF');

      when(() => assetRepository.getByCode(any())).thenAnswer(
        (_) async => Success(currencyFixture(id: 'USD', code: 'USD')),
      );
      when(() => assetRepository.getByIds(any())).thenAnswer(
        (_) async => Success(
          BatchLookup(
            found: [
              currencyFixture(id: 'CHF', code: 'CHF'),
              currencyFixture(id: 'USD', code: 'USD'),
            ],
            missing: [],
          ),
        ),
      );
    });

    test('returns the repository rates for a successful lookup', () async {
      // Given
      final rates = [
        exchangeRateFixture(baseAssetId: 'CHF', quoteAssetId: 'USD'),
      ];
      when(
        () => rateRepository.getByPair(baseAssetId: chf, quoteAssetId: usd),
      ).thenAnswer((_) async => Success(rates));

      // When
      final result = await useCase(baseAssetId: chf, quoteAssetId: usd);

      // Then
      expect(result.valueOrNull, same(rates));
      verify(
        () => rateRepository.getByPair(baseAssetId: chf, quoteAssetId: usd),
      ).called(1);
    });

    test('does not return rates with a missing referenced asset', () async {
      // Given
      final rates = [
        exchangeRateFixture(baseAssetId: 'CHF', quoteAssetId: 'USD'),
      ];
      when(
        () => rateRepository.getByPair(baseAssetId: chf, quoteAssetId: usd),
      ).thenAnswer((_) async => Success(rates));
      when(() => assetRepository.getByIds(any())).thenAnswer(
        (_) async =>
            Success(BatchLookup(found: [], missing: [rates.first.baseAssetId])),
      );

      // When
      final result = await useCase(baseAssetId: chf, quoteAssetId: usd);

      // Then
      expect(result.failureOrNull, isA<ReferencedAssetNotFoundFailure>());
    });

    test('propagates a pair-not-found failure unchanged', () async {
      // Given
      const failure = RateNotFoundFailure(message: 'pair missing');
      when(
        () => rateRepository.getByPair(baseAssetId: chf, quoteAssetId: usd),
      ).thenAnswer((_) async => failure);

      // When
      final result = await useCase(baseAssetId: chf, quoteAssetId: usd);

      // Then
      expect(result.failureOrNull, same(failure));
    });

    test('propagates another repository failure unchanged', () async {
      // Given
      const failure = RatePersistenceFailure(message: 'storage failure');
      when(
        () => rateRepository.getByPair(baseAssetId: chf, quoteAssetId: usd),
      ).thenAnswer((_) async => failure);

      // When
      final result = await useCase(baseAssetId: chf, quoteAssetId: usd);

      // Then
      expect(result.failureOrNull, same(failure));
    });

    test(
      'preserves pair direction and does not query the inverse pair',
      () async {
        // Given
        when(
          () => rateRepository.getByPair(baseAssetId: chf, quoteAssetId: usd),
        ).thenAnswer((_) async => RateNotFoundFailure());

        // When
        await useCase(baseAssetId: chf, quoteAssetId: usd);

        // Then
        verify(
          () => rateRepository.getByPair(baseAssetId: chf, quoteAssetId: usd),
        ).called(1);
        verifyNever(
          () => rateRepository.getByPair(baseAssetId: usd, quoteAssetId: chf),
        );
      },
    );

    test('rejects a non-USD quote without querying rates', () async {
      // Given
      final eur = AssetId.fromString('EUR');

      // When
      final result = await useCase(baseAssetId: chf, quoteAssetId: eur);

      // Then
      expect(result.failureOrNull, isA<UnsupportedPersistedRateQuoteFailure>());
      verifyNever(
        () => rateRepository.getByPair(
          baseAssetId: any(named: 'baseAssetId'),
          quoteAssetId: any(named: 'quoteAssetId'),
        ),
      );
    });

    test('returns not-found when USD is not configured', () async {
      // Given
      when(
        () => assetRepository.getByCode(any()),
      ).thenAnswer((_) async => const Success(null));

      // When
      final result = await useCase(baseAssetId: chf, quoteAssetId: usd);

      // Then
      expect(result.failureOrNull, isA<RecordNotFoundFailure>());
      verifyNever(
        () => rateRepository.getByPair(
          baseAssetId: any(named: 'baseAssetId'),
          quoteAssetId: any(named: 'quoteAssetId'),
        ),
      );
    });

    test('propagates a USD asset lookup failure unchanged', () async {
      // Given
      const failure = AssetNotFoundFailure(message: 'asset lookup failed');
      when(
        () => assetRepository.getByCode(any()),
      ).thenAnswer((_) async => failure);

      // When
      final result = await useCase(baseAssetId: chf, quoteAssetId: usd);

      // Then
      expect(result.failureOrNull, same(failure));
      verifyNever(
        () => rateRepository.getByPair(
          baseAssetId: any(named: 'baseAssetId'),
          quoteAssetId: any(named: 'quoteAssetId'),
        ),
      );
    });
  });
}
