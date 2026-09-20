@Tags(['application'])
library;

import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/ports/clock/clock.dart';
import 'package:axiom/src/core/repositories/batch_lookup.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/application/use_cases/get_assets_by_ids_use_case.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/assets/data/failures/asset_persistence_failure.dart';
import 'package:axiom/src/features/assets/domain/failures/referenced_asset_not_found_failure.dart';
import 'package:axiom/src/features/rates/application/failures/rate_synchronization_conflict_failure.dart';
import 'package:axiom/src/features/rates/application/models/rate_cache_entry.dart';
import 'package:axiom/src/features/rates/application/models/rate_source_observation.dart';
import 'package:axiom/src/features/rates/application/policies/rate_refresh_policy.dart';
import 'package:axiom/src/features/rates/application/ports/exchange_rate_source_adapter.dart';
import 'package:axiom/src/features/rates/application/services/synchronize_rate_service.dart';
import 'package:axiom/src/features/rates/data/cache/in_memory_latest_rate_cache.dart';
import 'package:axiom/src/features/rates/domain/entities/rate.dart';
import 'package:axiom/src/features/rates/domain/failures/rate_not_found_failure.dart';
import 'package:axiom/src/features/rates/data/failures/rate_persistence_failure.dart';
import 'package:mocktail/mocktail.dart';
import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/assets/asset_fixtures.dart';
import '../../../../../fixtures/features/rates/rate_fixtures.dart';
import '../../../../../mocks/asset_repository_mock.dart';
import '../../../../../mocks/rate_repository_mock.dart';

class _MockExchangeRateSourceAdapter extends Mock
    implements ExchangeRateSourceAdapter {}

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
    registerFallbackValue(exchangeRateFixture());
  });

  group('SynchronizeRateService', () {
    late MockAssetRepository assetRepository;
    late MockRateRepository rateRepository;
    late _MockExchangeRateSourceAdapter source;
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
      source = _MockExchangeRateSourceAdapter();
      cache = InMemoryLatestRateCache();
      clock = _MutableClock(DateTime.utc(2026, 9, 17, 12));

      eur = currencyFixture(id: 'asset-eur', code: 'EUR', name: 'Euro');

      usd = currencyFixture(id: 'asset-usd', code: 'USD', name: 'US Dollar');

      eurId = eur.id;
      usdId = usd.id;

      service = SynchronizeRateService(
        repository: rateRepository,
        getAssetsByIds: GetAssetsByIdsUseCase(assetRepository),
        source: source,
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

    void stubSource(RateSourceObservation value) {
      when(
        () => source.fetchLatest(baseCurrency: eur, quoteCurrency: usd),
      ).thenAnswer((_) async => Success(value));
    }

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
          () => source.fetchLatest(
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

        stubSource(sourceObservation);

        when(
          () => rateRepository.getLatestByPair(
            baseAssetId: eurId,
            quoteAssetId: usdId,
          ),
        ).thenAnswer(
          (_) async => const RateNotFoundFailure(message: 'missing'),
        );

        when(() => rateRepository.create(any())).thenAnswer((invocation) async {
          invocation.positionalArguments.single as Rate;

          return Success<void>(null);
        });

        // The generic helper above may be too broad for some analyzer versions.
        // Replace it with the explicit stub below if needed:
        //
        // when(() => rateRepository.create(any()))
        //     .thenAnswer((_) async => const Success(null));

        // When
        final result = await service(baseAssetId: eurId);

        // Then
        expect(result.isSuccess, isTrue);

        final synchronized = result.valueOrNull!;

        expect(synchronized.baseAssetId, eurId);
        expect(synchronized.quoteAssetId, usdId);
        expect(synchronized.rate, sourceObservation.rate);
        expect(synchronized.effectiveAt, sourceObservation.effectiveAt);

        final persisted =
            verify(() => rateRepository.create(captureAny())).captured.single
                as Rate;

        expect(persisted.baseAssetId, eurId);
        expect(persisted.quoteAssetId, usdId);
        expect(persisted.rate, Decimal.parse('1.123456789123456789'));
        expect(persisted.effectiveAt, DateTime.utc(2026, 9, 17, 10));

        final cached = cache.getLatest(baseAssetId: eurId, quoteAssetId: usdId);

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

        stubSource(
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

        stubSource(
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
        expect(result.failureOrNull, isA<RateSynchronizationConflictFailure>());

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

        stubSource(
          observation(rate: '1.08', effectiveAt: DateTime.utc(2026, 9, 16, 10)),
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

    test('persists source observation when it is financially newer', () async {
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

      stubSource(sourceObservation);

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
      expect(result.valueOrNull!.rate, Decimal.parse('1.11'));
      expect(result.valueOrNull!.effectiveAt, DateTime.utc(2026, 9, 17, 10));

      verify(() => rateRepository.create(any())).called(1);
    });

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

        stubSource(
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
          () => source.fetchLatest(baseCurrency: eur, quoteCurrency: usd),
        ).called(1);

        verifyNever(() => rateRepository.create(any()));
      },
    );

    test('propagates source failure and does not return stale cache', () async {
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

      const sourceFailure = RatePersistenceFailure(
        message: 'simulated source failure',
      );

      when(
        () => source.fetchLatest(baseCurrency: eur, quoteCurrency: usd),
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
    });

    test('propagates repository failure without changing cache', () async {
      // Given
      stubSource(observation());

      const failure = RatePersistenceFailure(message: 'database unavailable');

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

      expect(cache.getLatest(baseAssetId: eurId, quoteAssetId: usdId), isNull);
    });

    test('returns typed failure when a referenced asset is missing', () async {
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
        () => source.fetchLatest(
          baseCurrency: any(named: 'baseCurrency'),
          quoteCurrency: any(named: 'quoteCurrency'),
        ),
      );
    });

    test('returns typed failure when the base asset is absent from the lookup',
        () async {
      // Given
      when(() => assetRepository.getByIds(any())).thenAnswer(
        (_) async => Success(
          BatchLookup<Asset, AssetId>(found: [usd], missing: []),
        ),
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
        () => source.fetchLatest(
          baseCurrency: any(named: 'baseCurrency'),
          quoteCurrency: any(named: 'quoteCurrency'),
        ),
      );
    });

    test(
      'returns typed failure when the canonical quote asset is absent from the lookup',
      () async {
        // Given
        when(() => assetRepository.getByIds(any())).thenAnswer(
          (_) async => Success(
            BatchLookup<Asset, AssetId>(found: [eur], missing: []),
          ),
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
          () => source.fetchLatest(
            baseCurrency: any(named: 'baseCurrency'),
            quoteCurrency: any(named: 'quoteCurrency'),
          ),
        );
      },
    );

    test('propagates asset lookup failure without calling the source', () async {
      // Given
      const failure = AssetPersistenceFailure(message: 'asset lookup failed');

      when(
        () => assetRepository.getByIds(any()),
      ).thenAnswer((_) async => failure);

      // When
      final result = await service(baseAssetId: eurId);

      // Then
      expect(result.failureOrNull, same(failure));

      verifyNever(
        () => source.fetchLatest(
          baseCurrency: any(named: 'baseCurrency'),
          quoteCurrency: any(named: 'quoteCurrency'),
        ),
      );
    });

    test('propagates creation failure without caching the observation',
        () async {
      // Given
      stubSource(observation());

      when(
        () => rateRepository.getLatestByPair(
          baseAssetId: eurId,
          quoteAssetId: usdId,
        ),
      ).thenAnswer(
        (_) async => const RateNotFoundFailure(message: 'missing'),
      );

      const failure = RatePersistenceFailure(message: 'create failed');

      when(() => rateRepository.create(any())).thenAnswer((_) async => failure);

      // When
      final result = await service(baseAssetId: eurId);

      // Then
      expect(result.failureOrNull, same(failure));
      expect(cache.getLatest(baseAssetId: eurId, quoteAssetId: usdId), isNull);
    });

    test('rejects synchronization of canonical quote against itself', () async {
      await expectLater(service(baseAssetId: usdId), throwsArgumentError);

      verifyNever(() => assetRepository.getByIds(any()));
    });

    test(
      'regression: old financial timestamp does not immediately expire cache',
      () async {
        // Given
        //
        // Source reports yesterday's market close.
        stubSource(
          observation(rate: '1.10', effectiveAt: DateTime.utc(2026, 9, 16, 22)),
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

        clearInteractions(source);
        clearInteractions(rateRepository);
        clearInteractions(assetRepository);

        // When
        final second = await service(baseAssetId: eurId);

        // Then
        expect(second.isSuccess, isTrue);
        expect(second.valueOrNull!.id, first.valueOrNull!.id);

        verifyNever(
          () => source.fetchLatest(
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
}
