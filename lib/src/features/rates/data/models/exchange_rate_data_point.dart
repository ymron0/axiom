import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:decimal/decimal.dart';

/// Normalized exchange-rate observation produced by a data source.
///
/// This type represents external financial data before it becomes a persisted
/// domain [Rate].
///
/// Semantics are:
///
/// ```text
/// 1 base asset = rate × quote asset
/// ```
///
/// For example:
///
/// ```text
/// baseAssetId  = EUR
/// quoteAssetId = USD
/// rate         = 1.18
/// ```
///
/// means:
///
/// ```text
/// 1 EUR = 1.18 USD
/// ```
///
/// ## Invariants
///
/// - base and quote assets are different;
/// - [rate] is strictly positive; and
/// - [effectiveAt] is stored in UTC.
final class ExchangeRateDataPoint {
  /// Internal identity of the currency being valued.
  final AssetId baseAssetId;

  /// Internal identity of the currency in which the value is expressed.
  final AssetId quoteAssetId;

  /// Number of quote units corresponding to one base unit.
  final Decimal rate;

  /// Instant at which the external observation is financially effective.
  final DateTime effectiveAt;

  /// Creates a normalized external exchange-rate observation.
  ExchangeRateDataPoint({
    required this.baseAssetId,
    required this.quoteAssetId,
    required Decimal rate,
    required DateTime effectiveAt,
  }) : rate = _validateRate(rate),
       effectiveAt = effectiveAt.toUtc() {
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
        'Exchange rate must be greater than zero.',
      );
    }

    return rate;
  }
}
