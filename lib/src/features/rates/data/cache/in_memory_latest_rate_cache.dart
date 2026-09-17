import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/features/rates/application/models/rate_cache_entry.dart';
import 'package:axiom/src/features/rates/application/ports/latest_rate_cache.dart';

/// Process-local cache of latest synchronized rates.
///
/// Pair orientation is part of the cache key. EUR/USD and USD/EUR are
/// therefore independent entries.
///
/// The cache performs no expiration itself. Expiration belongs to
/// [RateRefreshPolicy], keeping storage and policy separate.
final class InMemoryLatestRateCache implements LatestRateCache {
  final Map<(AssetId, AssetId), RateCacheEntry> _entries =
      <(AssetId, AssetId), RateCacheEntry>{};

  @override
  RateCacheEntry? getLatest({
    required AssetId baseAssetId,
    required AssetId quoteAssetId,
  }) {
    return _entries[(baseAssetId, quoteAssetId)];
  }

  @override
  void put(RateCacheEntry entry) {
    final rate = entry.rate;

    _entries[(rate.baseAssetId, rate.quoteAssetId)] = entry;
  }

  @override
  void remove({required AssetId baseAssetId, required AssetId quoteAssetId}) {
    _entries.remove((baseAssetId, quoteAssetId));
  }

  @override
  void clear() {
    _entries.clear();
  }
}
