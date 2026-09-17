// coverage:ignore-file

import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/features/rates/application/models/rate_cache_entry.dart';

/// Cache containing only the latest synchronized observation for each pair.
///
/// This cache must not be used for historical/as-of resolution.
///
/// Historical rate resolution continues to use [RateRepository] because a
/// latest-only cache cannot answer historical questions correctly.
abstract interface class LatestRateCache {
  /// Returns the cached latest entry for the exact ordered pair.
  RateCacheEntry? getLatest({
    required AssetId baseAssetId,
    required AssetId quoteAssetId,
  });

  /// Stores or replaces the cached entry for its exact ordered pair.
  void put(RateCacheEntry entry);

  /// Removes the exact ordered pair from the cache.
  void remove({required AssetId baseAssetId, required AssetId quoteAssetId});

  /// Removes every cached latest rate.
  void clear();
}
