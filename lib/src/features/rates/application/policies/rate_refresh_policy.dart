import 'package:axiom/src/features/rates/application/models/rate_cache_entry.dart';

/// Determines whether a latest-rate cache entry should be refreshed.
///
/// Freshness is based exclusively on [RateCacheEntry.cachedAt].
///
/// It deliberately does not use `Rate.effectiveAt`, because the latter is a
/// financial timestamp supplied by the market-data provider.
///
/// ## Boundary semantics
///
/// An entry is stale when:
///
/// ```text
/// age >= maxAge
/// ```
///
/// Therefore an entry exactly [maxAge] old is refreshed.
///
/// A cache timestamp later than [now] is also refreshed. This avoids a clock
/// rollback causing an entry to remain fresh indefinitely.
final class RateRefreshPolicy {
  /// Maximum age of a cache entry before another synchronization is required.
  final Duration maxAge;

  /// Creates a refresh policy.
  ///
  /// Throws [ArgumentError] when [maxAge] is zero or negative.
  RateRefreshPolicy({required this.maxAge}) {
    if (maxAge.inMicroseconds <= 0) {
      throw ArgumentError.value(
        maxAge,
        'maxAge',
        'Rate refresh maximum age must be greater than zero.',
      );
    }
  }

  /// Whether [entry] must be refreshed at [now].
  bool shouldRefresh({
    required RateCacheEntry? entry,
    required DateTime now,
    bool forceRefresh = false,
  }) {
    if (forceRefresh) {
      return true;
    }

    if (entry == null) {
      return true;
    }

    final currentInstant = now.toUtc();

    if (entry.cachedAt.isAfter(currentInstant)) {
      return true;
    }

    final age = currentInstant.difference(entry.cachedAt);

    return age.compareTo(maxAge) >= 0;
  }
}
