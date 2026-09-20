import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:decimal/decimal.dart';

/// Application input for creating and persisting a market-price rate.
///
/// The base asset is the asset being priced, while the quote asset identifies
/// the currency in which one unit of the base asset is valued. Domain
/// validation is performed when the use case creates the rate entity.
final class CreateMarketPriceRateCommand {
  /// Market-priced asset.
  final AssetId baseAssetId;

  /// Currency in which the market price is expressed.
  final AssetId quoteAssetId;

  /// Number of quote units corresponding to one base-asset unit.
  final Decimal rate;

  /// Financial effective instant of the observation.
  final DateTime effectiveAt;

  /// Creates market-price creation input.
  const CreateMarketPriceRateCommand({
    required this.baseAssetId,
    required this.quoteAssetId,
    required this.rate,
    required this.effectiveAt,
  });
}
