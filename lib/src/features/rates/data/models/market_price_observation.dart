import 'package:axiom/src/features/assets/domain/value_objects/asset_code.dart';
import 'package:decimal/decimal.dart';

/// One externally observed market price for an ordered asset pair.
///
/// A market-price observation describes how many units of the
/// [quoteAssetCode] correspond to one unit of the [baseAssetCode].
///
/// For example:
///
/// ```text
/// base  = BTC
/// quote = USD
/// price = 65000
///
/// 1 BTC = 65000 USD
/// ```
///
/// This intentionally follows the same financial base/quote convention used
/// by the rates domain.
///
/// ## Ownership
///
/// This object belongs to the acquisition/data boundary. It uses [AssetCode]
/// rather than internal asset identities because an external market-data
/// provider does not own or know the application's [AssetId] values.
///
/// Resolving these codes to persisted assets is the responsibility of the
/// application layer.
///
/// Likewise, this object does not create a domain Rate, assign a RateId, or
/// persist anything.
///
/// ## Invariants
///
/// - [baseAssetCode] and [quoteAssetCode] must be different.
/// - [price] must be strictly greater than zero.
/// - [effectiveAt] is normalized to UTC.
///
/// ## Semantics
///
/// Pair orientation is significant.
///
/// A BTC/USD observation is not a USD/BTC observation. This model never
/// automatically inverts prices.
///
/// No rounding is performed. The exact [Decimal] supplied by the source is
/// retained.
final class MarketPriceObservation {
  /// Asset whose single unit is being priced.
  final AssetCode baseAssetCode;

  /// Asset in which the base asset's market value is expressed.
  final AssetCode quoteAssetCode;

  /// Number of quote-asset units corresponding to one base-asset unit.
  final Decimal price;

  /// Instant at which this market price was economically effective.
  final DateTime effectiveAt;

  /// Creates one validated market-price observation.
  ///
  /// Throws [ArgumentError] when:
  ///
  /// - the base and quote asset codes are identical; or
  /// - [price] is zero or negative.
  MarketPriceObservation({
    required this.baseAssetCode,
    required this.quoteAssetCode,
    required Decimal price,
    required DateTime effectiveAt,
  }) : price = _validatePrice(price),
       effectiveAt = effectiveAt.toUtc() {
    _validateAssetPair();
  }

  void _validateAssetPair() {
    if (baseAssetCode == quoteAssetCode) {
      throw ArgumentError.value(
        quoteAssetCode,
        'quoteAssetCode',
        'Base asset and quote asset must be different.',
      );
    }
  }

  static Decimal _validatePrice(Decimal price) {
    if (price <= Decimal.zero) {
      throw ArgumentError.value(
        price,
        'price',
        'Market price must be greater than zero.',
      );
    }

    return price;
  }
}
