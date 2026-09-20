part of 'asset.dart';

/// A commodity represented as an [Asset].
///
/// Examples include precious metals and other market-priced commodities.
///
/// Commodity assets can be valued and traded but cannot be used directly as
/// payment assets.
@MappableClass()
final class CommodityAsset extends Asset with CommodityAssetMappable {
  /// Creates a commodity asset.
  CommodityAsset({
    required super.id,
    required super.entityVersion,
    required super.createdAt,
    required super.modifiedAt,
    required super.name,
    required super.code,
    super.symbol,
    super.logo,
    required super.decimalPlaces,
  });

  /// Creates a commodity asset with generated identity and audit timestamps.
  factory CommodityAsset.create({
    required String name,
    required AssetCode code,
    String? symbol,
    EntityLogo? logo,
    required int decimalPlaces,
    Clock? clock,
  }) {
    final resolvedClock = clock ?? createClock();
    final now = resolvedClock.nowUtc;

    return CommodityAsset(
      id: AssetId.generate(),
      entityVersion: 1,
      createdAt: now,
      modifiedAt: now,
      name: name,
      code: code,
      symbol: symbol,
      logo: logo,
      decimalPlaces: decimalPlaces,
    );
  }

  /// Commodities can never be used directly for payments.
  @override
  bool get paymentEnabled => false;
}
