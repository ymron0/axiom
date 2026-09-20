@Tags(['application'])
library;

import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/ports/clock/clock.dart';
import 'package:axiom/src/core/repositories/batch_lookup.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/application/use_cases/get_assets_by_ids_use_case.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/assets/domain/failures/asset_repository_failure.dart';
import 'package:axiom/src/features/assets/domain/failures/referenced_asset_not_found_failure.dart';
import 'package:axiom/src/features/rates/application/failures/invalid_rate_asset_semantics_failure.dart';
import 'package:axiom/src/features/rates/application/failures/rate_synchronization_conflict_failure.dart';
import 'package:axiom/src/features/rates/application/models/rate_cache_entry.dart';
import 'package:axiom/src/features/rates/application/models/rate_source_observation.dart';
import 'package:axiom/src/features/rates/application/policies/rate_refresh_policy.dart';
import 'package:axiom/src/features/rates/application/ports/exchange_rate_source_adapter.dart';
import 'package:axiom/src/features/rates/application/ports/market_price_source_adapter.dart';
import 'package:axiom/src/features/rates/application/services/synchronize_rate_service.dart';
import 'package:axiom/src/features/rates/data/cache/in_memory_latest_rate_cache.dart';
import 'package:axiom/src/features/rates/domain/entities/rate.dart';
import 'package:axiom/src/features/rates/domain/failures/rate_not_found_failure.dart';
import 'package:axiom/src/features/rates/domain/failures/rate_repository_failure.dart';
import 'package:decimal/decimal.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/assets/asset_fixtures.dart';
import '../../../../../fixtures/features/rates/rate_fixtures.dart';
import '../../../../../mocks/asset_repository_mock.dart';
import '../../../../../mocks/rate_repository_mock.dart';

class _MockExchangeRateSourceAdapter extends Mock
    implements ExchangeRateSourceAdapter {}

class _MockMarketPriceSourceAdapter extends Mock
    implements MarketPriceSourceAdapter {}

final class _MutableClock implements Clock {
  _MutableClock(this.value);

  DateTime value;

  @override
  DateTime get now => value;

  @override
  DateTime get nowUtc => value.toUtc();
}

void main() {
  setUpAll(() {
    registerFallbackValue(AssetId.fromString('fallback-asset'));
    registerFallbackValue(<AssetId>[]);
    registerFallbackValue(currencyFixture());
    registerFallbackValue(cryptoAssetFixture());
    registerFallbackValue(stockAssetFixture());
    registerFallbackValue(commodityAssetFixture());
    registerFallbackValue(exchangeRateFixture());
    registerFallbackValue(marketPriceRateFixture());
  });

  group('SynchronizeRateService', () {
    late MockAssetRepository assetRepository;
    late MockRateRepository rateRepository;
    late _MockExchangeRateSourceAdapter exchangeRateSource;
    late _MockMarketPriceSourceAdapter marketPriceSource;
    late InMemoryLatestRateCache cache;
    late _MutableClock clock;
    late SynchronizeRateService service;

    late Currency eur;
    late Currency usd;

    late AssetId eurId;
    late AssetId usdId;

    setUp(() {
      assetRepository = MockAssetRepository();
      rateRepository = MockRateRepository();
      exchangeRateSource = _MockExchangeRateSourceAdapter();
      marketPriceSource = _MockMarketPriceSourceAdapter();
      cache = InMemoryLatestRateCache();
      clock = _MutableClock(DateTime.utc(2026, 9, 17, 12));

      eur = currencyFixture(id: 'asset-eur', code: 'EUR', name: 'Euro');
      usd = currencyFixture(id: 'asset-usd', code: 'USD', name: 'US Dollar');

      eurId = eur.id;
      usdId = usd.id;

      service = SynchronizeRateService(
        repository: rateRepository,
        getAssetsByIds: GetAssetsByIdsUseCase(assetRepository),
        exchangeRateSource: exchangeRateSource,
        marketPriceSource: marketPriceSource,
        cache: cache,
        refreshPolicy: RateRefreshPolicy(maxAge: const Duration(hours: 6)),
        canonicalBridgeAssetId: usdId,
        clock: clock,
      );

      when(() => assetRepository.getByIds(any())).thenAnswer(
        (_) async => Success(
          BatchLookup<Asset, AssetId>(found: [eur, usd], missing: []),
        ),
      );
    });

    RateSourceObservation observation({
      String rate = '1.10',
      DateTime? effectiveAt,
    }) {
      return RateSourceObservation(
        rate: Decimal.parse(rate),
        effectiveAt: effectiveAt ?? DateTime.utc(2026, 9, 17, 10),
      );
    }

    void stubExchangeRateSource(RateSourceObservation value) {
      when(
        () => exchangeRateSource.fetchLatest(
          baseCurrency: eur,
          quoteCurrency: usd,
        ),
      ).thenAnswer((_) async => Success(value));
    }

    group('currency base asset (ExchangeRate)', () {
      test(
        'returns a fresh cache entry without resolving assets or source',
        () async {
          // Given
          final cachedRate = exchangeRateFixture(
            id: 'cached-rate',
            baseAssetId: eurId.value,
            quoteAssetId: usdId.value,
            rate: '1.09',
            effectiveAt: DateTime.utc(2026, 9, 17, 8),
          );

          cache.put(
            RateCacheEntry(
              rate: cachedRate,
              cachedAt: clock.nowUtc.subtract(const Duration(hours: 1)),
            ),
          );

          // When
          final result = await service(baseAssetId: eurId);

          // Then
          expect(result.valueOrNull, same(cachedRate));

          verifyNever(() => assetRepository.getByIds(any()));

          verifyNever(
            () => exchangeRateSource.fetchLatest(
              baseCurrency: any(named: 'baseCurrency'),
              quoteCurrency: any(named: 'quoteCurrency'),
            ),
          );

          verifyNever(
            () => rateRepository.getLatestByPair(
              baseAssetId: any(named: 'baseAssetId'),
              quoteAssetId: any(named: 'quoteAssetId'),
            ),
          );
        },
      );

      test(
        'persists and caches a source observation when repository is empty',
        () async {
          // Given
          final sourceObservation = observation(
            rate: '1.123456789123456789',
            effectiveAt: DateTime.utc(2026, 9, 17, 10),
          );

          stubExchangeRateSource(sourceObservation);

          when(
            () => rateRepository.getLatestByPair(
              baseAssetId: eurId,
              quoteAssetId: usdId,
            ),
          ).thenAnswer(
            (_) async => const RateNotFoundFailure(message: 'missing'),
          );

          when(() => rateRepository.create(any())).thenAnswer((
            invocation,
          ) async {
            invocation.positionalArguments.single as Rate;
            return Success<void>(null);
          });

          // When
          final result = await service(baseAssetId: eurId);

          // Then
          expect(result.isSuccess, isTrue);

          final synchronized = result.valueOrNull!;

          expect(synchronized, isA<ExchangeRate>());
          expect(synchronized.baseAssetId, eurId);
          expect(synchronized.quoteAssetId, usdId);
          expect(synchronized.rate, sourceObservation.rate);
          expect(synchronized.effectiveAt, sourceObservation.effectiveAt);

          final persisted =
              verify(() => rateRepository.create(captureAny())).captured.single
                  as Rate;

          expect(persisted, isA<ExchangeRate>());
          expect(persisted.baseAssetId, eurId);
          expect(persisted.quoteAssetId, usdId);
          expect(persisted.rate, Decimal.parse('1.123456789123456789'));
          expect(persisted.effectiveAt, DateTime.utc(2026, 9, 17, 10));

          final cached = cache.getLatest(
            baseAssetId: eurId,
            quoteAssetId: usdId,
          );

          expect(cached, isNotNull);
          expect(cached!.rate.id, synchronized.id);
          expect(cached.cachedAt, clock.nowUtc);
        },
      );

      test(
        'does not create a duplicate when timestamp and value already exist',
        () async {
          // Given
          final existing = exchangeRateFixture(
            id: 'existing-rate',
            baseAssetId: eurId.value,
            quoteAssetId: usdId.value,
            rate: '1.10',
            effectiveAt: DateTime.utc(2026, 9, 17, 10),
          );

          stubExchangeRateSource(
            observation(rate: '1.10', effectiveAt: existing.effectiveAt),
          );

          when(
            () => rateRepository.getLatestByPair(
              baseAssetId: eurId,
              quoteAssetId: usdId,
            ),
          ).thenAnswer((_) async => Success(existing));

          // When
          final result = await service(baseAssetId: eurId);

          // Then
          expect(result.valueOrNull, same(existing));
          verifyNever(() => rateRepository.create(any()));
        },
      );

      test(
        'returns conflict when same effective timestamp has different value',
        () async {
          // Given
          final existing = exchangeRateFixture(
            id: 'existing-rate',
            baseAssetId: eurId.value,
            quoteAssetId: usdId.value,
            rate: '1.10',
            effectiveAt: DateTime.utc(2026, 9, 17, 10),
          );

          stubExchangeRateSource(
            observation(rate: '1.11', effectiveAt: existing.effectiveAt),
          );

          when(
            () => rateRepository.getLatestByPair(
              baseAssetId: eurId,
              quoteAssetId: usdId,
            ),
          ).thenAnswer((_) async => Success(existing));

          // When
          final result = await service(baseAssetId: eurId);

          // Then
          expect(
            result.failureOrNull,
            isA<RateSynchronizationConflictFailure>(),
          );
          verifyNever(() => rateRepository.create(any()));
          expect(
            cache.getLatest(baseAssetId: eurId, quoteAssetId: usdId),
            isNull,
          );
        },
      );

      test(
        'keeps newer persisted rate when source returns older observation',
        () async {
          // Given
          final existing = exchangeRateFixture(
            id: 'existing-newer-rate',
            baseAssetId: eurId.value,
            quoteAssetId: usdId.value,
            rate: '1.12',
            effectiveAt: DateTime.utc(2026, 9, 17, 10),
          );

          stubExchangeRateSource(
            observation(
              rate: '1.08',
              effectiveAt: DateTime.utc(2026, 9, 16, 10),
            ),
          );

          when(
            () => rateRepository.getLatestByPair(
              baseAssetId: eurId,
              quoteAssetId: usdId,
            ),
          ).thenAnswer((_) async => Success(existing));

          // When
          final result = await service(baseAssetId: eurId);

          // Then
          expect(result.valueOrNull, same(existing));
          verifyNever(() => rateRepository.create(any()));
          expect(
            cache.getLatest(baseAssetId: eurId, quoteAssetId: usdId)?.rate,
            same(existing),
          );
        },
      );

      test(
        'persists source observation when it is financially newer',
        () async {
          // Given
          final existing = exchangeRateFixture(
            id: 'existing-rate',
            baseAssetId: eurId.value,
            quoteAssetId: usdId.value,
            rate: '1.10',
            effectiveAt: DateTime.utc(2026, 9, 16, 10),
          );

          final sourceObservation = observation(
            rate: '1.11',
            effectiveAt: DateTime.utc(2026, 9, 17, 10),
          );

          stubExchangeRateSource(sourceObservation);

          when(
            () => rateRepository.getLatestByPair(
              baseAssetId: eurId,
              quoteAssetId: usdId,
            ),
          ).thenAnswer((_) async => Success(existing));

          when(
            () => rateRepository.create(any()),
          ).thenAnswer((_) async => const Success(null));

          // When
          final result = await service(baseAssetId: eurId);

          // Then
          expect(result.isSuccess, isTrue);
          expect(result.valueOrNull!, isA<ExchangeRate>());
          expect(result.valueOrNull!.rate, Decimal.parse('1.11'));
          expect(
            result.valueOrNull!.effectiveAt,
            DateTime.utc(2026, 9, 17, 10),
          );

          verify(() => rateRepository.create(any())).called(1);
        },
      );

      test(
        'force refresh bypasses a fresh cache but remains idempotent',
        () async {
          // Given
          final existing = exchangeRateFixture(
            id: 'existing-rate',
            baseAssetId: eurId.value,
            quoteAssetId: usdId.value,
            rate: '1.10',
            effectiveAt: DateTime.utc(2026, 9, 17, 10),
          );

          cache.put(RateCacheEntry(rate: existing, cachedAt: clock.nowUtc));

          stubExchangeRateSource(
            observation(rate: '1.10', effectiveAt: existing.effectiveAt),
          );

          when(
            () => rateRepository.getLatestByPair(
              baseAssetId: eurId,
              quoteAssetId: usdId,
            ),
          ).thenAnswer((_) async => Success(existing));

          // When
          final result = await service(baseAssetId: eurId, forceRefresh: true);

          // Then
          expect(result.valueOrNull, same(existing));

          verify(
            () => exchangeRateSource.fetchLatest(
              baseCurrency: eur,
              quoteCurrency: usd,
            ),
          ).called(1);

          verifyNever(() => rateRepository.create(any()));
        },
      );

      test(
        'returns InvalidRateAssetSemanticsFailure when persisted rate is not an ExchangeRate',
        () async {
          // Given — a MarketPriceRate is stored but the base asset is a Currency.
          final persistedMarketRate = marketPriceRateFixture(
            baseAssetId: eurId.value,
            quoteAssetId: usdId.value,
          );

          stubExchangeRateSource(observation());

          when(
            () => rateRepository.getLatestByPair(
              baseAssetId: eurId,
              quoteAssetId: usdId,
            ),
          ).thenAnswer((_) async => Success(persistedMarketRate));

          // When
          final result = await service(baseAssetId: eurId);

          // Then
          expect(result.failureOrNull, isA<InvalidRateAssetSemanticsFailure>());

          verifyNever(() => rateRepository.create(any()));
        },
      );
    });

    group('market-priced base asset (MarketPriceRate)', () {
      late CryptoAsset btc;
      late AssetId btcId;

      setUp(() {
        btc = cryptoAssetFixture(id: 'asset-btc', code: 'BTC', name: 'Bitcoin');
        btcId = btc.id;

        when(() => assetRepository.getByIds(any())).thenAnswer(
          (_) async => Success(
            BatchLookup<Asset, AssetId>(found: [btc, usd], missing: []),
          ),
        );
      });

      RateSourceObservation marketObservation({
        String rate = '65000',
        DateTime? effectiveAt,
      }) {
        return RateSourceObservation(
          rate: Decimal.parse(rate),
          effectiveAt: effectiveAt ?? DateTime.utc(2026, 9, 17, 10),
        );
      }

      void stubMarketPriceSource(RateSourceObservation value) {
        when(
          () =>
              marketPriceSource.fetchLatest(baseAsset: btc, quoteCurrency: usd),
        ).thenAnswer((_) async => Success(value));
      }

      test('persists a MarketPriceRate when repository is empty', () async {
        // Given
        stubMarketPriceSource(
          marketObservation(
            rate: '65000',
            effectiveAt: DateTime.utc(2026, 9, 17, 10),
          ),
        );

        when(
          () => rateRepository.getLatestByPair(
            baseAssetId: btcId,
            quoteAssetId: usdId,
          ),
        ).thenAnswer(
          (_) async => const RateNotFoundFailure(message: 'missing'),
        );

        when(
          () => rateRepository.create(any()),
        ).thenAnswer((_) async => const Success(null));

        // When
        final result = await service(baseAssetId: btcId);

        // Then
        expect(result.isSuccess, isTrue);

        final synchronized = result.valueOrNull!;
        expect(synchronized, isA<MarketPriceRate>());
        expect(synchronized.baseAssetId, btcId);
        expect(synchronized.quoteAssetId, usdId);
        expect(synchronized.rate, Decimal.parse('65000'));

        final persisted =
            verify(() => rateRepository.create(captureAny())).captured.single
                as Rate;
        expect(persisted, isA<MarketPriceRate>());
      });

      test(
        'does not create a duplicate when timestamp and value already exist',
        () async {
          // Given
          final existing = marketPriceRateFixture(
            id: 'existing-mpr',
            baseAssetId: btcId.value,
            quoteAssetId: usdId.value,
            rate: '65000',
            effectiveAt: DateTime.utc(2026, 9, 17, 10),
          );

          stubMarketPriceSource(
            marketObservation(rate: '65000', effectiveAt: existing.effectiveAt),
          );

          when(
            () => rateRepository.getLatestByPair(
              baseAssetId: btcId,
              quoteAssetId: usdId,
            ),
          ).thenAnswer((_) async => Success(existing));

          // When
          final result = await service(baseAssetId: btcId);

          // Then
          expect(result.valueOrNull, same(existing));
          verifyNever(() => rateRepository.create(any()));
        },
      );

      test(
        'returns InvalidRateAssetSemanticsFailure when persisted rate is not a MarketPriceRate',
        () async {
          // Given — an ExchangeRate is stored but the base asset is a CryptoAsset.
          final persistedExchangeRate = exchangeRateFixture(
            baseAssetId: btcId.value,
            quoteAssetId: usdId.value,
          );

          stubMarketPriceSource(marketObservation());

          when(
            () => rateRepository.getLatestByPair(
              baseAssetId: btcId,
              quoteAssetId: usdId,
            ),
          ).thenAnswer((_) async => Success(persistedExchangeRate));

          // When
          final result = await service(baseAssetId: btcId);

          // Then
          expect(result.failureOrNull, isA<InvalidRateAssetSemanticsFailure>());

          verifyNever(() => rateRepository.create(any()));
        },
      );

      test(
        'uses MarketPriceSourceAdapter, not ExchangeRateSourceAdapter',
        () async {
          // Given
          stubMarketPriceSource(marketObservation());

          when(
            () => rateRepository.getLatestByPair(
              baseAssetId: btcId,
              quoteAssetId: usdId,
            ),
          ).thenAnswer(
            (_) async => const RateNotFoundFailure(message: 'missing'),
          );

          when(
            () => rateRepository.create(any()),
          ).thenAnswer((_) async => const Success(null));

          // When
          await service(baseAssetId: btcId);

          // Then
          verify(
            () => marketPriceSource.fetchLatest(
              baseAsset: btc,
              quoteCurrency: usd,
            ),
          ).called(1);

          verifyNever(
            () => exchangeRateSource.fetchLatest(
              baseCurrency: any(named: 'baseCurrency'),
              quoteCurrency: any(named: 'quoteCurrency'),
            ),
          );
        },
      );

      test('fetches and persists MarketPriceRate for StockAsset', () async {
        // Given
        final stock = stockAssetFixture(
          id: 'asset-nvda',
          code: 'NVDA',
          name: 'NVIDIA Corp',
        );
        final stockId = stock.id;

        when(() => assetRepository.getByIds(any())).thenAnswer(
          (_) async => Success(
            BatchLookup<Asset, AssetId>(found: [stock, usd], missing: []),
          ),
        );

        when(
          () => marketPriceSource.fetchLatest(
            baseAsset: stock,
            quoteCurrency: usd,
          ),
        ).thenAnswer((_) async => Success(marketObservation(rate: '120')));

        when(
          () => rateRepository.getLatestByPair(
            baseAssetId: stockId,
            quoteAssetId: usdId,
          ),
        ).thenAnswer(
          (_) async => const RateNotFoundFailure(message: 'missing'),
        );

        when(
          () => rateRepository.create(any()),
        ).thenAnswer((_) async => const Success(null));

        // When
        final result = await service(baseAssetId: stockId);

        // Then
        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull, isA<MarketPriceRate>());
        expect(result.valueOrNull?.baseAssetId, stockId);
        expect(result.valueOrNull?.rate, Decimal.parse('120'));

        verify(
          () => marketPriceSource.fetchLatest(
            baseAsset: stock,
            quoteCurrency: usd,
          ),
        ).called(1);
      });

      test('fetches and persists MarketPriceRate for CommodityAsset', () async {
        // Given
        final commodity = commodityAssetFixture(
          id: 'asset-xau',
          code: 'XAU',
          name: 'Gold',
        );
        final commodityId = commodity.id;

        when(() => assetRepository.getByIds(any())).thenAnswer(
          (_) async => Success(
            BatchLookup<Asset, AssetId>(found: [commodity, usd], missing: []),
          ),
        );

        when(
          () => marketPriceSource.fetchLatest(
            baseAsset: commodity,
            quoteCurrency: usd,
          ),
        ).thenAnswer((_) async => Success(marketObservation(rate: '2500')));

        when(
          () => rateRepository.getLatestByPair(
            baseAssetId: commodityId,
            quoteAssetId: usdId,
          ),
        ).thenAnswer(
          (_) async => const RateNotFoundFailure(message: 'missing'),
        );

        when(
          () => rateRepository.create(any()),
        ).thenAnswer((_) async => const Success(null));

        // When
        final result = await service(baseAssetId: commodityId);

        // Then
        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull, isA<MarketPriceRate>());
        expect(result.valueOrNull?.baseAssetId, commodityId);
        expect(result.valueOrNull?.rate, Decimal.parse('2500'));

        verify(
          () => marketPriceSource.fetchLatest(
            baseAsset: commodity,
            quoteCurrency: usd,
          ),
        ).called(1);
      });
    });

    group('asset resolution failures', () {
      test(
        'returns typed failure when a referenced asset is missing',
        () async {
          // Given
          when(() => assetRepository.getByIds(any())).thenAnswer(
            (_) async => Success(
              BatchLookup<Asset, AssetId>(found: [eur], missing: [usdId]),
            ),
          );

          // When
          final result = await service(baseAssetId: eurId);

          // Then
          expect(result.failureOrNull, isA<ReferencedAssetNotFoundFailure>());

          verifyNever(
            () => exchangeRateSource.fetchLatest(
              baseCurrency: any(named: 'baseCurrency'),
              quoteCurrency: any(named: 'quoteCurrency'),
            ),
          );
        },
      );

      test(
        'returns typed failure when the base asset is absent from the lookup',
        () async {
          // Given
          when(() => assetRepository.getByIds(any())).thenAnswer(
            (_) async =>
                Success(BatchLookup<Asset, AssetId>(found: [usd], missing: [])),
          );

          // When
          final result = await service(baseAssetId: eurId);

          // Then
          expect(result.failureOrNull, isA<ReferencedAssetNotFoundFailure>());
          expect(
            result.failureOrNull!.message,
            'Rate synchronization base asset was not found: ${eurId.value}',
          );

          verifyNever(
            () => exchangeRateSource.fetchLatest(
              baseCurrency: any(named: 'baseCurrency'),
              quoteCurrency: any(named: 'quoteCurrency'),
            ),
          );
        },
      );

      test(
        'returns typed failure when the canonical quote asset is absent from the lookup',
        () async {
          // Given
          when(() => assetRepository.getByIds(any())).thenAnswer(
            (_) async =>
                Success(BatchLookup<Asset, AssetId>(found: [eur], missing: [])),
          );

          // When
          final result = await service(baseAssetId: eurId);

          // Then
          expect(result.failureOrNull, isA<ReferencedAssetNotFoundFailure>());
          expect(
            result.failureOrNull!.message,
            'Canonical rate quote asset was not found: ${usdId.value}',
          );

          verifyNever(
            () => exchangeRateSource.fetchLatest(
              baseCurrency: any(named: 'baseCurrency'),
              quoteCurrency: any(named: 'quoteCurrency'),
            ),
          );
        },
      );

      test(
        'returns InvalidRateAssetSemanticsFailure when the canonical quote asset is not a Currency',
        () async {
          // Given — the bridge asset ID resolves to a CryptoAsset instead of a Currency.
          final nonCurrencyQuote = cryptoAssetFixture(
            id: usdId.value,
            code: 'USDT',
          );

          when(() => assetRepository.getByIds(any())).thenAnswer(
            (_) async => Success(
              BatchLookup<Asset, AssetId>(
                found: [eur, nonCurrencyQuote],
                missing: [],
              ),
            ),
          );

          // When
          final result = await service(baseAssetId: eurId);

          // Then
          expect(result.failureOrNull, isA<InvalidRateAssetSemanticsFailure>());
          expect(
            result.failureOrNull!.message,
            contains('Canonical persisted-rate quote asset must be a Currency'),
          );

          verifyNever(
            () => exchangeRateSource.fetchLatest(
              baseCurrency: any(named: 'baseCurrency'),
              quoteCurrency: any(named: 'quoteCurrency'),
            ),
          );
        },
      );

      test(
        'propagates asset lookup failure without calling the source',
        () async {
          // Given
          const failure = AssetRepositoryFailure(
            message: 'asset lookup failed',
          );

          when(
            () => assetRepository.getByIds(any()),
          ).thenAnswer((_) async => failure);

          // When
          final result = await service(baseAssetId: eurId);

          // Then
          expect(result.failureOrNull, same(failure));

          verifyNever(
            () => exchangeRateSource.fetchLatest(
              baseCurrency: any(named: 'baseCurrency'),
              quoteCurrency: any(named: 'quoteCurrency'),
            ),
          );
        },
      );
    });

    group('source and repository failures', () {
      test(
        'propagates source failure and does not return stale cache',
        () async {
          // Given
          final stale = exchangeRateFixture(
            id: 'stale-rate',
            baseAssetId: eurId.value,
            quoteAssetId: usdId.value,
          );

          cache.put(
            RateCacheEntry(
              rate: stale,
              cachedAt: clock.nowUtc.subtract(const Duration(hours: 7)),
            ),
          );

          const sourceFailure = RateRepositoryFailure(
            message: 'simulated source failure',
          );

          when(
            () => exchangeRateSource.fetchLatest(
              baseCurrency: eur,
              quoteCurrency: usd,
            ),
          ).thenAnswer((_) async => sourceFailure);

          // When
          final result = await service(baseAssetId: eurId);

          // Then
          expect(result.failureOrNull, same(sourceFailure));

          verifyNever(
            () => rateRepository.getLatestByPair(
              baseAssetId: any(named: 'baseAssetId'),
              quoteAssetId: any(named: 'quoteAssetId'),
            ),
          );
        },
      );

      test('propagates repository failure without changing cache', () async {
        // Given
        when(
          () => exchangeRateSource.fetchLatest(
            baseCurrency: eur,
            quoteCurrency: usd,
          ),
        ).thenAnswer((_) async => Success(observation()));

        const failure = RateRepositoryFailure(message: 'database unavailable');

        when(
          () => rateRepository.getLatestByPair(
            baseAssetId: eurId,
            quoteAssetId: usdId,
          ),
        ).thenAnswer((_) async => failure);

        // When
        final result = await service(baseAssetId: eurId);

        // Then
        expect(result.failureOrNull, same(failure));
        expect(
          cache.getLatest(baseAssetId: eurId, quoteAssetId: usdId),
          isNull,
        );
      });

      test(
        'propagates creation failure without caching the observation',
        () async {
          // Given
          when(
            () => exchangeRateSource.fetchLatest(
              baseCurrency: eur,
              quoteCurrency: usd,
            ),
          ).thenAnswer((_) async => Success(observation()));

          when(
            () => rateRepository.getLatestByPair(
              baseAssetId: eurId,
              quoteAssetId: usdId,
            ),
          ).thenAnswer(
            (_) async => const RateNotFoundFailure(message: 'missing'),
          );

          const failure = RateRepositoryFailure(message: 'create failed');

          when(
            () => rateRepository.create(any()),
          ).thenAnswer((_) async => failure);

          // When
          final result = await service(baseAssetId: eurId);

          // Then
          expect(result.failureOrNull, same(failure));
          expect(
            cache.getLatest(baseAssetId: eurId, quoteAssetId: usdId),
            isNull,
          );
        },
      );
    });

    group('guard invariants', () {
      test(
        'rejects synchronization of canonical quote against itself',
        () async {
          await expectLater(service(baseAssetId: usdId), throwsArgumentError);
          verifyNever(() => assetRepository.getByIds(any()));
        },
      );

      test(
        'regression: old financial timestamp does not immediately expire cache',
        () async {
          // Given
          //
          // Source reports yesterday's market close.
          when(
            () => exchangeRateSource.fetchLatest(
              baseCurrency: eur,
              quoteCurrency: usd,
            ),
          ).thenAnswer(
            (_) async => Success(
              observation(
                rate: '1.10',
                effectiveAt: DateTime.utc(2026, 9, 16, 22),
              ),
            ),
          );

          when(
            () => rateRepository.getLatestByPair(
              baseAssetId: eurId,
              quoteAssetId: usdId,
            ),
          ).thenAnswer(
            (_) async => const RateNotFoundFailure(message: 'missing'),
          );

          when(
            () => rateRepository.create(any()),
          ).thenAnswer((_) async => const Success(null));

          // First synchronization.
          final first = await service(baseAssetId: eurId);
          expect(first.isSuccess, isTrue);

          // One hour passes.
          clock.value = clock.value.add(const Duration(hours: 1));

          clearInteractions(exchangeRateSource);
          clearInteractions(rateRepository);
          clearInteractions(assetRepository);

          // When
          final second = await service(baseAssetId: eurId);

          // Then
          expect(second.isSuccess, isTrue);
          expect(second.valueOrNull!.id, first.valueOrNull!.id);

          verifyNever(
            () => exchangeRateSource.fetchLatest(
              baseCurrency: any(named: 'baseCurrency'),
              quoteCurrency: any(named: 'quoteCurrency'),
            ),
          );

          verifyNever(
            () => rateRepository.getLatestByPair(
              baseAssetId: any(named: 'baseAssetId'),
              quoteAssetId: any(named: 'quoteAssetId'),
            ),
          );
        },
      );
    });
  });
}
