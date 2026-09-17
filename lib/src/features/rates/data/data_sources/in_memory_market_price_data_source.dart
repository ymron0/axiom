import 'dart:collection';

import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_code.dart';
import 'package:axiom/src/features/rates/data/data_sources/market_price_data_source.dart';
import 'package:axiom/src/features/rates/data/failures/market_price_data_source_failure.dart';
import 'package:axiom/src/features/rates/data/failures/market_price_not_found_failure.dart';
import 'package:axiom/src/features/rates/data/models/market_price_observation.dart';

/// Deterministic in-memory implementation of [MarketPriceDataSource].
///
/// This implementation is suitable for tests, fixtures, development, and
/// application wiring before a live provider adapter is introduced.
///
/// ## Ownership
///
/// Supplied observations are copied into an internal index during
/// construction. Subsequent changes to the caller's source collection cannot
/// affect this data source.
///
/// ## Selection semantics
///
/// Only the latest observation for each exact ordered asset pair is retained.
///
/// "Latest" means the greatest [MarketPriceObservation.effectiveAt] value.
///
/// Input order does not affect which observation is selected.
///
/// Conflicting observations for the same pair and exact effective timestamp
/// are rejected during construction because selecting one would otherwise
/// depend on arbitrary input order.
///
/// Exact duplicate observations with the same pair, timestamp, and price are
/// harmless and are collapsed.
///
/// ## Pair semantics
///
/// No inverse or cross-price calculation is performed.
///
/// If BTC/USD exists but USD/BTC does not, requesting USD/BTC returns
/// [MarketPriceNotFoundFailure].
final class InMemoryMarketPriceDataSource implements MarketPriceDataSource {
  /// Creates a source populated with [observations].
  ///
  /// Throws [ArgumentError] when two observations contain:
  ///
  /// - the same ordered pair;
  /// - the same [MarketPriceObservation.effectiveAt]; and
  /// - different prices.
  InMemoryMarketPriceDataSource({
    Iterable<MarketPriceObservation> observations =
        const <MarketPriceObservation>[],
  }) : _latestByPair = UnmodifiableMapView(
         _buildLatestByPairIndex(observations),
       );

  final Map<_MarketPricePairKey, MarketPriceObservation> _latestByPair;

  @override
  Future<Result<MarketPriceObservation, MarketPriceDataSourceFailure>>
  getLatest({
    required AssetCode baseAssetCode,
    required AssetCode quoteAssetCode,
  }) async {
    if (baseAssetCode == quoteAssetCode) {
      throw ArgumentError.value(
        quoteAssetCode,
        'quoteAssetCode',
        'Base asset and quote asset must be different.',
      );
    }

    final key = _MarketPricePairKey(
      baseAssetCode: baseAssetCode,
      quoteAssetCode: quoteAssetCode,
    );

    final observation = _latestByPair[key];

    if (observation == null) {
      return MarketPriceNotFoundFailure(
        message:
            'No market price is available for '
            '${baseAssetCode.value}/${quoteAssetCode.value}.',
      );
    }

    return Success(observation);
  }

  static Map<_MarketPricePairKey, MarketPriceObservation>
  _buildLatestByPairIndex(Iterable<MarketPriceObservation> observations) {
    final latestByPair = <_MarketPricePairKey, MarketPriceObservation>{};

    for (final observation in observations) {
      final key = _MarketPricePairKey(
        baseAssetCode: observation.baseAssetCode,
        quoteAssetCode: observation.quoteAssetCode,
      );

      final current = latestByPair[key];

      if (current == null) {
        latestByPair[key] = observation;
        continue;
      }

      if (observation.effectiveAt.isAfter(current.effectiveAt)) {
        latestByPair[key] = observation;
        continue;
      }

      if (observation.effectiveAt.isBefore(current.effectiveAt)) {
        continue;
      }

      if (observation.price != current.price) {
        throw ArgumentError.value(
          observation,
          'observations',
          'Conflicting market prices exist for '
              '${observation.baseAssetCode.value}/'
              '${observation.quoteAssetCode.value} '
              'at ${observation.effectiveAt.toIso8601String()}.',
        );
      }
    }

    return latestByPair;
  }
}

/// Immutable key for one ordered market-price pair.
final class _MarketPricePairKey {
  final AssetCode baseAssetCode;
  final AssetCode quoteAssetCode;

  const _MarketPricePairKey({
    required this.baseAssetCode,
    required this.quoteAssetCode,
  });

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is _MarketPricePairKey &&
            other.baseAssetCode == baseAssetCode &&
            other.quoteAssetCode == quoteAssetCode;
  }

  @override
  int get hashCode => Object.hash(baseAssetCode, quoteAssetCode);
}
