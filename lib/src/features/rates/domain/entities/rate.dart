import 'package:axiom/src/core/domain/entities/base/audited_entity.dart';
import 'package:axiom/src/core/domain/mappers/decimal_mapper.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/rate_id.dart';
import 'package:dart_mappable/dart_mappable.dart';
import 'package:decimal/decimal.dart';

part 'rate.mapper.dart';

/// Base domain entity for a value relating one asset to another.
///
/// A rate represents an ordered asset pair consisting of a [baseAssetId] and
/// a [quoteAssetId]. The [rate] states how many units of the quote asset
/// correspond to exactly one unit of the base asset.
///
/// For example, for BTC/USD:
///
/// ```text
/// base asset  = BTC
/// quote asset = USD
/// rate        = 65000
///
/// 1 BTC = 65000 USD
/// ```
///
/// Reversing the asset pair changes the economic meaning of the rate.
/// BTC/USD and USD/BTC are therefore distinct rates and their values are
/// reciprocals of one another.
///
/// The terms "base asset" and "quote asset" are standard financial pair
/// terminology. They are unrelated to the application's configured valuation
/// currency.
///
/// ## Time semantics
///
/// [effectiveAt] identifies the instant at which the rate applies in the
/// financial domain. It is distinct from [createdAt] and [modifiedAt], which
/// describe the lifecycle of this entity inside the application.
///
/// [effectiveAt] is normalized to UTC when the entity is constructed.
///
/// A rate received today may therefore legitimately have an [effectiveAt]
/// from yesterday if the underlying source reports yesterday's closing rate.
///
/// ## Invariants
///
/// - [id] must contain a valid [RateId].
/// - [baseAssetId] and [quoteAssetId] must identify different assets.
/// - [rate] must be strictly greater than zero.
/// - [effectiveAt] is represented in UTC.
/// - [entityVersion] must be greater than zero.
/// - [modifiedAt] must not precede [createdAt].
///
/// ## Contract
///
/// Concrete rate types define what kind of financial observation the rate
/// represents, but must preserve the base/quote semantics defined here.
///
/// Subclasses must not reinterpret [rate] as "base units per quote unit".
/// It always represents:
///
/// ```text
/// 1 base asset = rate × quote asset
/// ```
@MappableClass(includeCustomMappers: [DecimalMapper()])
abstract class Rate extends AuditedEntity<RateId> with RateMappable {
  /// The asset for which one unit is being valued.
  ///
  /// In BTC/USD, BTC is the base asset.
  final AssetId baseAssetId;

  /// The asset in which the base asset's value is expressed.
  ///
  /// In BTC/USD, USD is the quote asset.
  final AssetId quoteAssetId;

  /// The number of quote-asset units corresponding to one base-asset unit.
  ///
  /// For BTC/USD at 65000:
  ///
  /// ```text
  /// 1 BTC = 65000 USD
  /// ```
  ///
  /// This value is always strictly greater than zero.
  final Decimal rate;

  /// The instant at which this rate is economically effective.
  ///
  /// This is domain time and must not be confused with [createdAt] or
  /// [modifiedAt], which are application audit timestamps.
  ///
  /// The supplied value is normalized to UTC.
  final DateTime effectiveAt;

  /// Creates the common state shared by all rate types.
  ///
  /// Throws an [ArgumentError] when:
  ///
  /// - [baseAssetId] and [quoteAssetId] identify the same asset;
  /// - [rate] is zero or negative;
  /// - [entityVersion] is less than one; or
  /// - [modifiedAt] precedes [createdAt].
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
