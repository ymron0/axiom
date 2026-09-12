import 'package:axiom/src/core/failures/record_already_exists_failure.dart';
import 'package:axiom/src/core/failures/rate_not_found_failure.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/rates/application/services/resolve_conversion_rate_service.dart';
import 'package:axiom/src/features/rates/domain/services/rate_conversion_service.dart';
import 'package:decimal/decimal.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/rates/rate_fixtures.dart';
import '../../../../../mocks/rate_repository_mock.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(AssetId.fromString('fallback'));
    registerFallbackValue(DateTime.utc(1970));
  });

  group('ResolveConversionRateService', () {
    late MockRateRepository repository;
    late ResolveConversionRateService service;
    late AssetId eur;
    late AssetId chf;
    late AssetId usd;
    late DateTime at;

    setUp(() {
      repository = MockRateRepository();
      eur = AssetId.fromString('asset-eur');
      chf = AssetId.fromString('asset-chf');
      usd = AssetId.fromString('asset-usd');
      at = DateTime.utc(2026, 9, 10, 12);
      service = ResolveConversionRateService(
        repository: repository,
        canonicalBridgeAssetId: usd,
        rateConversion: const RateConversionService(),
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

    test('resolves a direct-to-USD conversion', () async {
      final eurUsd = exchangeRateFixture(
        id: 'eur-usd',
        baseAssetId: 'asset-eur',
        quoteAssetId: 'asset-usd',
        rate: '0.8',
      );
      when(
        () => repository.getAtOrBefore(
          baseAssetId: eur,
          quoteAssetId: usd,
          effectiveAt: at,
        ),
      ).thenAnswer((_) async => Success(eurUsd));

      final result = await service(fromAssetId: eur, toAssetId: usd, at: at);

      expect(result.valueOrNull, Decimal.parse('0.8'));
      verify(
        () => repository.getAtOrBefore(
          baseAssetId: eur,
          quoteAssetId: usd,
          effectiveAt: at,
        ),
      ).called(1);
    });

    test('resolves an inverse-from-USD conversion', () async {
      final eurUsd = exchangeRateFixture(
        id: 'eur-usd',
        baseAssetId: 'asset-eur',
        quoteAssetId: 'asset-usd',
        rate: '0.8',
      );
      when(
        () => repository.getAtOrBefore(
          baseAssetId: eur,
          quoteAssetId: usd,
          effectiveAt: at,
        ),
      ).thenAnswer((_) async => Success(eurUsd));

      final result = await service(fromAssetId: usd, toAssetId: eur, at: at);

      expect(result.valueOrNull, Decimal.parse('1.25'));
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
    });

    test('resolves a cross-rate through USD', () async {
      final eurUsd = exchangeRateFixture(
        id: 'eur-usd',
        baseAssetId: 'asset-eur',
        quoteAssetId: 'asset-usd',
        rate: '1.18',
      );
      final chfUsd = exchangeRateFixture(
        id: 'chf-usd',
        baseAssetId: 'asset-chf',
        quoteAssetId: 'asset-usd',
        rate: '1.26',
      );
      when(
        () => repository.getAtOrBefore(
          baseAssetId: eur,
          quoteAssetId: usd,
          effectiveAt: at,
        ),
      ).thenAnswer((_) async => Success(eurUsd));
      when(
        () => repository.getAtOrBefore(
          baseAssetId: chf,
          quoteAssetId: usd,
          effectiveAt: at,
        ),
      ).thenAnswer((_) async => Success(chfUsd));

      final result = await service(fromAssetId: eur, toAssetId: chf, at: at);

      expect(result.valueOrNull, Decimal.parse('0.936507936507936507'));
      verifyNever(
        () => repository.getAtOrBefore(
          baseAssetId: eur,
          quoteAssetId: chf,
          effectiveAt: at,
        ),
      );
      verifyNever(
        () => repository.getAtOrBefore(
          baseAssetId: chf,
          quoteAssetId: eur,
          effectiveAt: at,
        ),
      );
    });

    test('returns the missing canonical bridge rate failure', () async {
      const failure = RateNotFoundFailure(message: 'EUR/USD missing');
      when(
        () => repository.getAtOrBefore(
          baseAssetId: eur,
          quoteAssetId: usd,
          effectiveAt: at,
        ),
      ).thenAnswer((_) async => failure);

      final result = await service(fromAssetId: eur, toAssetId: chf, at: at);

      expect(result.failureOrNull, same(failure));
      verifyNever(
        () => repository.getAtOrBefore(
          baseAssetId: chf,
          quoteAssetId: usd,
          effectiveAt: at,
        ),
      );
    });

    test('propagates non-not-found failures unchanged', () async {
      const failure = RecordAlreadyExistsFailure(message: 'storage failure');
      when(
        () => repository.getAtOrBefore(
          baseAssetId: eur,
          quoteAssetId: usd,
          effectiveAt: at,
        ),
      ).thenAnswer((_) async => failure);

      final result = await service(fromAssetId: eur, toAssetId: chf, at: at);

      expect(result.failureOrNull, same(failure));
    });
  });
}
