import 'package:axiom/src/core/domain/entities/base/audited_entity.dart';
import 'package:axiom/src/core/domain/mappers/decimal_mapper.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/rate_id.dart';
import 'package:axiom/src/core/ports/clock/clock.dart';
import 'package:axiom/src/core/ports/clock/clock_factory.dart';
import 'package:dart_mappable/dart_mappable.dart';
import 'package:decimal/decimal.dart';

part 'exchange_rate.dart';
part 'market_price_rate.dart';
part 'rate.mapper.dart';

/// Base domain entity for an observed value relating one asset to another.
///
/// A rate represents an ordered asset pair consisting of a [baseAssetId] and
/// a [quoteAssetId]. The [rate] states how many units of the quote asset
/// correspond to exactly one unit of the base asset.
///
/// For example:
///
/// ```text
/// base asset  = BTC
/// quote asset = USD
/// rate        = 65000
///
/// 1 BTC = 65000 USD
/// ```
///
/// Reversing the asset pair changes the economic meaning of the observation.
///
/// ## Rate types
///
/// Concrete rate types describe the financial nature of the observation.
///
/// Examples include:
///
/// - currency exchange rates; and
/// - market prices for crypto, stocks, and commodities.
///
/// The mathematical base/quote semantics are identical for every subtype.
///
/// ## Time semantics
///
/// [effectiveAt] identifies the instant at which the observation applies in
/// the financial domain.
///
/// It is distinct from [createdAt] and [modifiedAt], which describe the
/// lifecycle of this entity inside the application.
///
/// [effectiveAt] is normalized to UTC.
///
/// ## Invariants
///
/// - [baseAssetId] and [quoteAssetId] identify different assets.
/// - [rate] is strictly greater than zero.
/// - [effectiveAt] is stored in UTC.
/// - inherited audited-entity invariants remain valid.
///
/// ## Contract
///
/// Concrete rate types must preserve:
///
/// ```text
/// 1 base asset = rate × quote asset
/// ```
///
/// Asset-type compatibility requires access to the referenced Asset entities
/// and is therefore validated at the application boundary.
@MappableClass(includeCustomMappers: [DecimalMapper()])
sealed class Rate extends AuditedEntity<RateId> with RateMappable {
  /// The asset for which one unit is being valued.
  final AssetId baseAssetId;

  /// The asset in which the base asset's value is expressed.
  final AssetId quoteAssetId;

  /// Number of quote-asset units corresponding to one base-asset unit.
  final Decimal rate;

  /// Instant at which this observation is financially effective.
  final DateTime effectiveAt;

  /// Creates common state shared by all rate types.
  @MappableConstructor()
  Rate({
    required super.id,
    required this.baseAssetId,
    required this.quoteAssetId,
    required Decimal rate,
    required DateTime effectiveAt,
    required super.entityVersion,
    required super.createdAt,
    required super.modifiedAt,
  }) : rate = _validateRate(rate),
       effectiveAt = effectiveAt.toUtc() {
    _validateAssetPair();
  }

  void _validateAssetPair() {
    if (baseAssetId == quoteAssetId) {
      throw ArgumentError.value(
        quoteAssetId,
        'quoteAssetId',
        'Base asset and quote asset must be different.',
      );
    }
  }

  static Decimal _validateRate(Decimal rate) {
    if (rate <= Decimal.zero) {
      throw ArgumentError.value(
        rate,
        'rate',
        'Rate must be greater than zero.',
      );
    }

    return rate;
  }
}
