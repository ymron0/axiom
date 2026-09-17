@Tags(['integration', 'rates', 'persistence'])
library;

import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/application/use_cases/get_assets_by_ids_use_case.dart';
import 'package:axiom/src/features/assets/data/repositories/sembast_asset_repository_impl.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/rates/application/models/rate_source_observation.dart';
import 'package:axiom/src/features/rates/application/policies/rate_refresh_policy.dart';
import 'package:axiom/src/features/rates/application/ports/exchange_rate_source_adapter.dart';
import 'package:axiom/src/features/rates/application/services/synchronize_rate_service.dart';
import 'package:axiom/src/features/rates/data/cache/in_memory_latest_rate_cache.dart';
import 'package:axiom/src/features/rates/data/repositories/sembast_rate_repository_impl.dart';
import 'package:decimal/decimal.dart';
import 'package:test/test.dart';

import '../../../fixtures/core/persistence/persistence_test_environment.dart';
import '../../../fixtures/features/assets/asset_fixtures.dart';

void main() {
  group('Rate synchronization integration', () {
    test(
      'downloads, persists, caches, and subsequently reuses a fresh rate',
      () async {
        // Given
        final environment = await PersistenceTestEnvironment.createMemory(
          prefix: 'rate-synchronization-integration-',
        );

        final lifecycle = environment.createLifecycle();
        final openResult = await lifecycle.open();

        expect(openResult.isSuccess, isTrue);

        final database = openResult.valueOrNull!;

        final assetRepository = SembastAssetRepositoryImpl(database: database);

        final rateRepository = SembastRateRepositoryImpl(database: database);

        final eur = currencyFixture(id: 'asset-eur', name: 'Euro', code: 'EUR');

        final usd = currencyFixture(
          id: 'asset-usd',
          name: 'US Dollar',
          code: 'USD',
        );

        expect((await assetRepository.create(eur)).isSuccess, isTrue);

        expect((await assetRepository.create(usd)).isSuccess, isTrue);

        final source = _FakeExchangeRateSourceAdapter(
          observation: RateSourceObservation(
            rate: Decimal.parse('1.123456789'),
            effectiveAt: DateTime.utc(2026, 9, 17, 10),
          ),
        );

        final cache = InMemoryLatestRateCache();

        final service = SynchronizeRateService(
          repository: rateRepository,
          getAssetsByIds: GetAssetsByIdsUseCase(assetRepository),
          source: source,
          cache: cache,
          refreshPolicy: RateRefreshPolicy(maxAge: const Duration(hours: 6)),
          canonicalBridgeAssetId: usd.id,
          clock: FixedClock(DateTime.utc(2026, 9, 17, 12)),
        );

        // When: synchronize from the external boundary.
        final firstResult = await service(baseAssetId: eur.id);

        // Then
        expect(firstResult.isSuccess, isTrue);

        final synchronized = firstResult.valueOrNull!;

        expect(synchronized.baseAssetId, eur.id);
        expect(synchronized.quoteAssetId, usd.id);
        expect(synchronized.rate, Decimal.parse('1.123456789'));
        expect(synchronized.effectiveAt, DateTime.utc(2026, 9, 17, 10));

        // The observation really reached persistent storage.
        final persistedResult = await rateRepository.getLatestByPair(
          baseAssetId: eur.id,
          quoteAssetId: usd.id,
        );

        expect(persistedResult.isSuccess, isTrue);
        expect(persistedResult.valueOrNull!.id, synchronized.id);

        // Cache contains the same persisted entity.
        final cached = cache.getLatest(
          baseAssetId: eur.id,
          quoteAssetId: usd.id,
        );

        expect(cached, isNotNull);
        expect(cached!.rate.id, synchronized.id);

        expect(source.callCount, 1);

        // When: request synchronization again while cache is fresh.
        final secondResult = await service(baseAssetId: eur.id);

        // Then: no second provider request and no duplicate persistence.
        expect(secondResult.isSuccess, isTrue);
        expect(secondResult.valueOrNull!.id, synchronized.id);
        expect(source.callCount, 1);

        final observations = await rateRepository.getByPair(
          baseAssetId: eur.id,
          quoteAssetId: usd.id,
        );

        expect(observations.isSuccess, isTrue);
        expect(observations.valueOrNull, hasLength(1));

        await lifecycle.close();
      },
    );
  });
}

final class _FakeExchangeRateSourceAdapter
    implements ExchangeRateSourceAdapter {
  final RateSourceObservation observation;

  int callCount = 0;

  _FakeExchangeRateSourceAdapter({required this.observation});

  @override
  Future<Result<RateSourceObservation, BaseFailure>> fetchLatest({
    required Currency baseCurrency,
    required Currency quoteCurrency,
  }) async {
    callCount++;

    expect(baseCurrency.code.value, 'EUR');
    expect(quoteCurrency.code.value, 'USD');

    return Success(observation);
  }
}
