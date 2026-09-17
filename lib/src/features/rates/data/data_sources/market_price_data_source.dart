// coverage:ignore-file

import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_code.dart';
import 'package:axiom/src/features/rates/data/failures/market_price_data_source_failure.dart';
import 'package:axiom/src/features/rates/data/models/market_price_observation.dart';

/// Acquisition boundary for externally supplied market prices.
///
/// A data source answers questions about raw externally observed prices. It
/// does not own persisted Rates or Assets.
///
/// ## Asset ownership
///
/// Callers identify assets through [AssetCode] values because provider-facing
/// integrations must not depend on internal [AssetId] values.
///
/// Translating source codes into domain asset identities belongs to the
/// application layer.
///
/// ## Pair semantics
///
/// Asset pairs are ordered.
///
/// For:
///
/// ```text
/// BTC/USD = 65000
/// ```
///
/// BTC is the base asset and USD is the quote asset.
///
/// Implementations must not:
///
/// - silently reverse a pair;
/// - calculate the reciprocal of another observation;
/// - derive cross-prices through a third asset; or
/// - return a different quote asset than the one requested.
///
/// Those are rate-resolution concerns outside this boundary.
///
/// ## Failure behavior
///
/// Expected acquisition failures are returned through
/// [MarketPriceDataSourceFailure].
///
/// Programmer errors and violated internal assumptions must not be converted
/// into arbitrary source failures.
abstract interface class MarketPriceDataSource {
  /// Returns the latest available observation for the exact ordered pair.
  ///
  /// [baseAssetCode] identifies the asset being priced.
  /// [quoteAssetCode] identifies the asset in which that price is expressed.
  ///
  /// Returns [MarketPriceNotFoundFailure] when the source contains no
  /// observation for the exact ordered pair.
  ///
  /// Concrete external implementations may additionally return failures such
  /// as source-unavailable or invalid-response failures.
  ///
  /// Implementations must not synthesize an inverse or cross-price.
  ///
  /// Throws [ArgumentError] when [baseAssetCode] and [quoteAssetCode] are
  /// identical because such a request does not represent a market-price pair.
  Future<Result<MarketPriceObservation, MarketPriceDataSourceFailure>>
  getLatest({
    required AssetCode baseAssetCode,
    required AssetCode quoteAssetCode,
  });
}
