import 'package:axiom/src/core/failures/record_already_exists_failure.dart';
import 'package:axiom/src/core/failures/record_not_found_failure.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/repositories/batch_lookup.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/application/use_cases/get_assets_by_ids_use_case.dart';
import 'package:axiom/src/features/rates/application/services/resolve_conversion_rate_service.dart';
import 'package:axiom/src/features/rates/application/services/validate_rate_assets_service.dart';
import 'package:axiom/src/features/rates/application/use_cases/get_rate_at_use_case.dart';
import 'package:axiom/src/features/rates/domain/services/rate_conversion_service.dart';
import 'package:decimal/decimal.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/rates/rate_fixtures.dart';
import '../../../../../fixtures/features/assets/asset_fixtures.dart';
import '../../../../../mocks/asset_repository_mock.dart';
import '../../../../../mocks/rate_repository_mock.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(AssetId.fromString('fallback'));
    registerFallbackValue(<AssetId>[]);
    registerFallbackValue(DateTime.utc(1970));
  });

  group('ResolveConversionRateService', () {
    late MockRateRepository repository;
    late MockAssetRepository assetRepository;
    late ResolveConversionRateService service;
    late AssetId eur;
    late AssetId usd;
    late DateTime at;

    setUp(() {
      assetRepository = MockAssetRepository();
      repository = MockRateRepository();
      service = ResolveConversionRateService(
        getRateAt: GetRateAtUseCase(
          repository: repository,
          validateRateAssets: ValidateRateAssetsService(
            getAssetsByIds: GetAssetsByIdsUseCase(assetRepository),
          ),
        ),
        rateConversion: const RateConversionService(),
      );
      eur = AssetId.fromString('EUR');
      usd = AssetId.fromString('USD');
      at = DateTime.utc(2026, 9, 10, 12);

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

    test('returns one without looking up a same-asset conversion', () async {
      final result = await service(fromAssetId: eur, toAssetId: eur, at: at);

      expect(result.valueOrNull, Decimal.one);
      verifyNever(
        () => repository.getAtOrBefore(
          baseAssetId: any(named: 'baseAssetId'),
          quoteAssetId: any(named: 'quoteAssetId'),
          effectiveAt: any(named: 'effectiveAt'),
        ),
      );
    });

    test(
      'returns the direct rate and does not query the reverse pair',
      () async {
        final direct = exchangeRateFixture(
          id: 'direct-rate',
          baseAssetId: 'EUR',
          quoteAssetId: 'USD',
          rate: '0.8',
        );
        when(
          () => repository.getAtOrBefore(
            baseAssetId: eur,
            quoteAssetId: usd,
            effectiveAt: at,
          ),
        ).thenAnswer((_) async => Success(direct));

        final result = await service(fromAssetId: eur, toAssetId: usd, at: at);

        expect(result.valueOrNull, Decimal.parse('0.8'));
        verify(
          () => repository.getAtOrBefore(
            baseAssetId: eur,
            quoteAssetId: usd,
            effectiveAt: at,
          ),
        ).called(1);
        verifyNever(
          () => repository.getAtOrBefore(
            baseAssetId: usd,
            quoteAssetId: eur,
            effectiveAt: at,
          ),
        );
      },
    );

    test(
      'inverts a reverse rate precisely when direct rate is missing',
      () async {
        final reverse = exchangeRateFixture(
          id: 'reverse-rate',
          baseAssetId: 'USD',
          quoteAssetId: 'EUR',
          rate: '0.8',
        );
        when(
          () => repository.getAtOrBefore(
            baseAssetId: eur,
            quoteAssetId: usd,
            effectiveAt: at,
          ),
        ).thenAnswer((_) async => const RecordNotFoundFailure());
        when(
          () => repository.getAtOrBefore(
            baseAssetId: usd,
            quoteAssetId: eur,
            effectiveAt: at,
          ),
        ).thenAnswer((_) async => Success(reverse));

        final result = await service(fromAssetId: eur, toAssetId: usd, at: at);

        expect(result.valueOrNull, Decimal.parse('1.25'));
        verify(
          () => repository.getAtOrBefore(
            baseAssetId: eur,
            quoteAssetId: usd,
            effectiveAt: at,
          ),
        ).called(1);
        verify(
          () => repository.getAtOrBefore(
            baseAssetId: usd,
            quoteAssetId: eur,
            effectiveAt: at,
          ),
        ).called(1);
      },
    );

    test(
      'preserves configured precision when inverting a repeating reverse rate',
      () async {
        final reverse = exchangeRateFixture(
          id: 'reverse-rate',
          baseAssetId: 'USD',
          quoteAssetId: 'EUR',
          rate: '3',
        );
        when(
          () => repository.getAtOrBefore(
            baseAssetId: eur,
            quoteAssetId: usd,
            effectiveAt: at,
          ),
        ).thenAnswer((_) async => const RecordNotFoundFailure());
        when(
          () => repository.getAtOrBefore(
            baseAssetId: usd,
            quoteAssetId: eur,
            effectiveAt: at,
          ),
        ).thenAnswer((_) async => Success(reverse));

        final result = await service(fromAssetId: eur, toAssetId: usd, at: at);

        expect(result.valueOrNull, Decimal.parse('0.333333333333333333'));
      },
    );

    test(
      'returns reverse not-found when both directions are missing',
      () async {
        const directFailure = RecordNotFoundFailure(message: 'direct');
        const reverseFailure = RecordNotFoundFailure(message: 'reverse');
        when(
          () => repository.getAtOrBefore(
            baseAssetId: eur,
            quoteAssetId: usd,
            effectiveAt: at,
          ),
        ).thenAnswer((_) async => directFailure);
        when(
          () => repository.getAtOrBefore(
            baseAssetId: usd,
            quoteAssetId: eur,
            effectiveAt: at,
          ),
        ).thenAnswer((_) async => reverseFailure);

        final result = await service(fromAssetId: eur, toAssetId: usd, at: at);

        expect(result.failureOrNull, same(reverseFailure));
        verify(
          () => repository.getAtOrBefore(
            baseAssetId: eur,
            quoteAssetId: usd,
            effectiveAt: at,
          ),
        ).called(1);
        verify(
          () => repository.getAtOrBefore(
            baseAssetId: usd,
            quoteAssetId: eur,
            effectiveAt: at,
          ),
        ).called(1);
      },
    );

    test(
      'propagates a direct non-not-found failure without reverse lookup',
      () async {
        const failure = RecordAlreadyExistsFailure(message: 'storage failure');
        when(
          () => repository.getAtOrBefore(
            baseAssetId: eur,
            quoteAssetId: usd,
            effectiveAt: at,
          ),
        ).thenAnswer((_) async => failure);

        final result = await service(fromAssetId: eur, toAssetId: usd, at: at);

        expect(result.failureOrNull, same(failure));
        verify(
          () => repository.getAtOrBefore(
            baseAssetId: eur,
            quoteAssetId: usd,
            effectiveAt: at,
          ),
        ).called(1);
        verifyNever(
          () => repository.getAtOrBefore(
            baseAssetId: usd,
            quoteAssetId: eur,
            effectiveAt: at,
          ),
        );
      },
    );

    test('propagates a reverse non-not-found failure unchanged', () async {
      const failure = RecordAlreadyExistsFailure(message: 'storage failure');
      when(
        () => repository.getAtOrBefore(
          baseAssetId: eur,
          quoteAssetId: usd,
          effectiveAt: at,
        ),
      ).thenAnswer((_) async => RecordNotFoundFailure());
      when(
        () => repository.getAtOrBefore(
          baseAssetId: usd,
          quoteAssetId: eur,
          effectiveAt: at,
        ),
      ).thenAnswer((_) async => failure);

      final result = await service(fromAssetId: eur, toAssetId: usd, at: at);

      expect(result.failureOrNull, same(failure));
      verify(
        () => repository.getAtOrBefore(
          baseAssetId: eur,
          quoteAssetId: usd,
          effectiveAt: at,
        ),
      ).called(1);
      verify(
        () => repository.getAtOrBefore(
          baseAssetId: usd,
          quoteAssetId: eur,
          effectiveAt: at,
        ),
      ).called(1);
    });
  });
}
