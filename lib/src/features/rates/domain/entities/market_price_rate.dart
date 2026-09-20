part of 'rate.dart';

/// A market-price observation for a non-currency financial asset.
///
/// Typical examples include:
///
/// ```text
/// BTC/USD
/// NVDA/USD
/// XAU/USD
/// ```
///
/// The inherited rate semantics remain:
///
/// ```text
/// 1 base asset = rate × quote asset
/// ```
///
/// ## Asset semantics
///
/// The base asset is expected to be a market-priced non-currency asset such
/// as a CryptoAsset, StockAsset, or CommodityAsset.
///
/// The quote asset is expected to be a Currency.
///
/// Because this entity stores only typed asset IDs, those relationships are
/// validated by the application layer where complete Asset entities are
/// available.
///
/// ## Persistence
///
/// Under the current rates persistence policy, market prices are persisted
/// against the canonical bridge currency, currently USD.
@MappableClass()
final class MarketPriceRate extends Rate with MarketPriceRateMappable {
  /// Creates a persisted market-price observation.
  @MappableConstructor()
  MarketPriceRate({
    required super.id,
    required super.baseAssetId,
    required super.quoteAssetId,
    required super.rate,
    required super.effectiveAt,
    required super.entityVersion,
    required super.createdAt,
    required super.modifiedAt,
  });

  /// Creates a new market-price observation.
  factory MarketPriceRate.create({
    required AssetId baseAssetId,
    required AssetId quoteAssetId,
    required Decimal rate,
    required DateTime effectiveAt,
    Clock? clock,
  }) {
    final resolvedClock = clock ?? createClock();
    final now = resolvedClock.nowUtc;

    return MarketPriceRate(
      id: RateId.generate(),
      baseAssetId: baseAssetId,
      quoteAssetId: quoteAssetId,
      rate: rate,
      effectiveAt: effectiveAt,
      entityVersion: 1,
      createdAt: now,
      modifiedAt: now,
    );
  }
}
