@Tags(['data'])
library;

import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/features/rates/application/models/rate_cache_entry.dart';
import 'package:axiom/src/features/rates/data/cache/in_memory_latest_rate_cache.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/rates/rate_fixtures.dart';

void main() {
  group('InMemoryLatestRateCache', () {
    late InMemoryLatestRateCache cache;

    final eur = AssetId.fromString('asset-eur');
    final usd = AssetId.fromString('asset-usd');

    setUp(() {
      cache = InMemoryLatestRateCache();
    });

    test('returns null when pair is not cached', () {
      expect(cache.getLatest(baseAssetId: eur, quoteAssetId: usd), isNull);
    });

    test('stores and returns an entry for the exact ordered pair', () {
      // Given
      final rate = exchangeRateFixture(
        baseAssetId: eur.value,
        quoteAssetId: usd.value,
      );

      final entry = RateCacheEntry(
        rate: rate,
        cachedAt: DateTime.utc(2026, 9, 17, 10),
      );

      // When
      cache.put(entry);

      // Then
      expect(cache.getLatest(baseAssetId: eur, quoteAssetId: usd), same(entry));
    });

    test('keeps reverse pair separate', () {
      // Given
      final direct = RateCacheEntry(
        rate: exchangeRateFixture(
          id: 'eur-usd',
          baseAssetId: eur.value,
          quoteAssetId: usd.value,
        ),
        cachedAt: DateTime.utc(2026, 9, 17, 10),
      );

      final reverse = RateCacheEntry(
        rate: exchangeRateFixture(
          id: 'usd-eur',
          baseAssetId: usd.value,
          quoteAssetId: eur.value,
          rate: '0.91',
        ),
        cachedAt: DateTime.utc(2026, 9, 17, 10),
      );

      // When
      cache
        ..put(direct)
        ..put(reverse);

      // Then
      expect(
        cache.getLatest(baseAssetId: eur, quoteAssetId: usd),
        same(direct),
      );

      expect(
        cache.getLatest(baseAssetId: usd, quoteAssetId: eur),
        same(reverse),
      );
    });

    test('replaces an existing entry for the same pair', () {
      // Given
      final first = RateCacheEntry(
        rate: exchangeRateFixture(
          id: 'rate-old',
          baseAssetId: eur.value,
          quoteAssetId: usd.value,
          rate: '1.08',
        ),
        cachedAt: DateTime.utc(2026, 9, 17, 8),
      );

      final second = RateCacheEntry(
        rate: exchangeRateFixture(
          id: 'rate-new',
          baseAssetId: eur.value,
          quoteAssetId: usd.value,
          rate: '1.09',
        ),
        cachedAt: DateTime.utc(2026, 9, 17, 10),
      );

      // When
      cache
        ..put(first)
        ..put(second);

      // Then
      expect(
        cache.getLatest(baseAssetId: eur, quoteAssetId: usd),
        same(second),
      );
    });

    test('removes only the requested pair', () {
      // Given
      cache
        ..put(
          RateCacheEntry(
            rate: exchangeRateFixture(
              id: 'direct',
              baseAssetId: eur.value,
              quoteAssetId: usd.value,
            ),
            cachedAt: DateTime.utc(2026, 9, 17),
          ),
        )
        ..put(
          RateCacheEntry(
            rate: exchangeRateFixture(
              id: 'reverse',
              baseAssetId: usd.value,
              quoteAssetId: eur.value,
              rate: '0.91',
            ),
            cachedAt: DateTime.utc(2026, 9, 17),
          ),
        );

      // When
      cache.remove(baseAssetId: eur, quoteAssetId: usd);

      // Then
      expect(cache.getLatest(baseAssetId: eur, quoteAssetId: usd), isNull);

      expect(cache.getLatest(baseAssetId: usd, quoteAssetId: eur), isNotNull);
    });

    test('clear removes all cached entries', () {
      // Given
      cache.put(
        RateCacheEntry(
          rate: exchangeRateFixture(
            baseAssetId: eur.value,
            quoteAssetId: usd.value,
          ),
          cachedAt: DateTime.utc(2026, 9, 17),
        ),
      );

      // When
      cache.clear();

      // Then
      expect(cache.getLatest(baseAssetId: eur, quoteAssetId: usd), isNull);
    });
  });
}
