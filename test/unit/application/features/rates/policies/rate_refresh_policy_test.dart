@Tags(['application'])
library;

import 'package:axiom/src/features/rates/application/models/rate_cache_entry.dart';
import 'package:axiom/src/features/rates/application/policies/rate_refresh_policy.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/rates/rate_fixtures.dart';

void main() {
  group('RateRefreshPolicy', () {
    final now = DateTime.utc(2026, 9, 17, 12);

    late RateRefreshPolicy policy;

    setUp(() {
      policy = RateRefreshPolicy(maxAge: const Duration(hours: 6));
    });

    RateCacheEntry entry({required DateTime cachedAt, DateTime? effectiveAt}) {
      return RateCacheEntry(
        rate: exchangeRateFixture(
          effectiveAt: effectiveAt ?? DateTime.utc(2026, 9, 17, 8),
        ),
        cachedAt: cachedAt,
      );
    }

    test('refreshes when no cache entry exists', () {
      expect(policy.shouldRefresh(entry: null, now: now), isTrue);
    });

    test('keeps an entry younger than max age', () {
      expect(
        policy.shouldRefresh(
          entry: entry(
            cachedAt: now.subtract(const Duration(hours: 5, minutes: 59)),
          ),
          now: now,
        ),
        isFalse,
      );
    });

    test('refreshes exactly at the max-age boundary', () {
      expect(
        policy.shouldRefresh(
          entry: entry(cachedAt: now.subtract(const Duration(hours: 6))),
          now: now,
        ),
        isTrue,
      );
    });

    test('refreshes an entry older than max age', () {
      expect(
        policy.shouldRefresh(
          entry: entry(cachedAt: now.subtract(const Duration(hours: 7))),
          now: now,
        ),
        isTrue,
      );
    });

    test('force refresh bypasses a fresh entry', () {
      expect(
        policy.shouldRefresh(
          entry: entry(cachedAt: now.subtract(const Duration(minutes: 1))),
          now: now,
          forceRefresh: true,
        ),
        isTrue,
      );
    });

    test('refreshes a cache timestamp in the future', () {
      expect(
        policy.shouldRefresh(
          entry: entry(cachedAt: now.add(const Duration(minutes: 1))),
          now: now,
        ),
        isTrue,
      );
    });

    test(
      'uses cache time rather than financial effective time for freshness',
      () {
        // Given
        //
        // Yesterday's closing rate was downloaded only five minutes ago.
        final cached = entry(
          cachedAt: now.subtract(const Duration(minutes: 5)),
          effectiveAt: DateTime.utc(2026, 9, 16, 22),
        );

        // When
        final shouldRefresh = policy.shouldRefresh(entry: cached, now: now);

        // Then
        expect(shouldRefresh, isFalse);
      },
    );

    test('normalizes the supplied current instant by UTC instant', () {
      // Given
      final offsetNow = DateTime.parse('2026-09-17T14:00:00+02:00');

      // When
      final shouldRefresh = policy.shouldRefresh(
        entry: entry(cachedAt: DateTime.utc(2026, 9, 17, 7)),
        now: offsetNow,
      );

      // Then
      expect(shouldRefresh, isFalse);
    });

    test('rejects zero max age', () {
      expect(
        () => RateRefreshPolicy(maxAge: Duration.zero),
        throwsArgumentError,
      );
    });

    test('rejects negative max age', () {
      expect(
        () => RateRefreshPolicy(maxAge: const Duration(seconds: -1)),
        throwsArgumentError,
      );
    });
  });
}
