part of 'asset.dart';

/// A publicly or privately traded stock represented as an [Asset].
///
/// Stocks may be held, valued, traded, and referenced by accounts or market
/// data, but they are not direct payment instruments.
@MappableClass()
final class StockAsset extends Asset with StockAssetMappable {
  /// Creates a stock asset.
  StockAsset({
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

  /// Creates a stock asset with generated identity and audit timestamps.
  factory StockAsset.create({
    required String name,
    required AssetCode code,
    String? symbol,
    EntityLogo? logo,
    required int decimalPlaces,
    Clock? clock,
  }) {
    final resolvedClock = clock ?? createClock();
    final now = resolvedClock.nowUtc;

    return StockAsset(
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

  /// Stocks can never be used directly for payments.
  @override
  bool get paymentEnabled => false;
}
