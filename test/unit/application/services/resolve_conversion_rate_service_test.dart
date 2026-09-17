@Tags(['application'])
library;

import 'package:axiom/src/features/assets/domain/failures/referenced_asset_not_found_failure.dart';
import 'package:axiom/src/features/rates/domain/failures/rate_not_found_failure.dart';
import 'package:axiom/src/features/rates/domain/failures/rate_persistence_failure.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/application/services/resolve_conversion_rate_service.dart';
import 'package:axiom/src/features/rates/domain/services/rate_conversion_service.dart';
import 'package:decimal/decimal.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../fixtures/features/rates/rate_fixtures.dart';
import '../../../mocks/get_rate_at_use_case_mock.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(AssetId.fromString('fallback'));
    registerFallbackValue(DateTime.utc(1970));
  });

  group('ResolveConversionRateService', () {
    late MockGetRateAtUseCase getRateAt;
    late ResolveConversionRateService service;
    late AssetId eur;
    late AssetId chf;
    late AssetId usd;
    late DateTime at;

    setUp(() {
      getRateAt = MockGetRateAtUseCase();
      eur = AssetId.fromString('asset-eur');
      chf = AssetId.fromString('asset-chf');
      usd = AssetId.fromString('asset-usd');
      at = DateTime.utc(2026, 9, 10, 12);
      service = ResolveConversionRateService(
        getRateAt: getRateAt,
        canonicalBridgeAssetId: usd,
        rateConversion: const RateConversionService(),
      );
    });

    test('returns one without looking up a same-asset conversion', () async {
      final result = await service(fromAssetId: eur, toAssetId: eur, at: at);

      expect(result.valueOrNull, Decimal.one);
      verifyNever(
        () => getRateAt(
          baseAssetId: any(named: 'baseAssetId'),
          quoteAssetId: any(named: 'quoteAssetId'),
          at: any(named: 'at'),
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
        () => getRateAt(
          baseAssetId: eur,
          quoteAssetId: usd,
          at: at,
        ),
      ).thenAnswer((_) async => Success(eurUsd));

      final result = await service(fromAssetId: eur, toAssetId: usd, at: at);

      expect(result.valueOrNull, Decimal.parse('0.8'));
      verify(
        () => getRateAt(
          baseAssetId: eur,
          quoteAssetId: usd,
          at: at,
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
        () => getRateAt(
          baseAssetId: eur,
          quoteAssetId: usd,
          at: at,
        ),
      ).thenAnswer((_) async => Success(eurUsd));

      final result = await service(fromAssetId: usd, toAssetId: eur, at: at);

      expect(result.valueOrNull, Decimal.parse('1.25'));
      verify(
        () => getRateAt(
          baseAssetId: eur,
          quoteAssetId: usd,
          at: at,
        ),
      ).called(1);
      verifyNever(
        () => getRateAt(
          baseAssetId: usd,
          quoteAssetId: eur,
          at: at,
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
        () => getRateAt(
          baseAssetId: eur,
          quoteAssetId: usd,
          at: at,
        ),
      ).thenAnswer((_) async => Success(eurUsd));
      when(
        () => getRateAt(
          baseAssetId: chf,
          quoteAssetId: usd,
          at: at,
        ),
      ).thenAnswer((_) async => Success(chfUsd));

      final result = await service(fromAssetId: eur, toAssetId: chf, at: at);

      expect(result.valueOrNull, Decimal.parse('0.936507936507936507'));
      verifyNever(
        () => getRateAt(
          baseAssetId: eur,
          quoteAssetId: chf,
          at: at,
        ),
      );
      verifyNever(
        () => getRateAt(
          baseAssetId: chf,
          quoteAssetId: eur,
          at: at,
        ),
      );
    });

    test('returns the missing canonical bridge rate failure', () async {
      const failure = RateNotFoundFailure(message: 'EUR/USD missing');
      when(
        () => getRateAt(
          baseAssetId: eur,
          quoteAssetId: usd,
          at: at,
        ),
      ).thenAnswer((_) async => failure);

      final result = await service(fromAssetId: eur, toAssetId: chf, at: at);

      expect(result.failureOrNull, same(failure));
      verifyNever(
        () => getRateAt(
          baseAssetId: chf,
          quoteAssetId: usd,
          at: at,
        ),
      );
    });

    test('propagates non-not-found failures unchanged', () async {
      const failure = RatePersistenceFailure(message: 'storage failure');
      when(
        () => getRateAt(
          baseAssetId: eur,
          quoteAssetId: usd,
          at: at,
        ),
      ).thenAnswer((_) async => failure);

      final result = await service(fromAssetId: eur, toAssetId: chf, at: at);

      expect(result.failureOrNull, same(failure));
    });

    test('propagates referenced-asset failures unchanged', () async {
      // Given
      const failure = ReferencedAssetNotFoundFailure(
        message: 'Referenced rate asset was not found: asset-eur',
      );
      when(
        () => getRateAt(
          baseAssetId: eur,
          quoteAssetId: usd,
          at: at,
        ),
      ).thenAnswer((_) async => failure);

      // When
      final result = await service(fromAssetId: eur, toAssetId: usd, at: at);

      // Then
      expect(result.failureOrNull, same(failure));
    });
  });
}
