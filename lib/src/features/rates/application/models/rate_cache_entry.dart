import 'package:axiom/src/features/rates/domain/entities/rate.dart';

/// One latest-rate cache entry.
///
/// [rate.effectiveAt] represents financial time.
///
/// [cachedAt] represents infrastructure time: when this observation was last
/// successfully synchronized into the latest-rate cache.
///
/// Keeping these timestamps independent is essential. A provider may report
/// yesterday's closing observation even though it was downloaded moments ago.
final class RateCacheEntry {
  /// The persisted rate represented by this cache entry.
  final Rate rate;

  /// The instant at which the application refreshed this cache entry.
  final DateTime cachedAt;

  /// Creates a cache entry.
  RateCacheEntry({required this.rate, required DateTime cachedAt})
    : cachedAt = cachedAt.toUtc();
}
