part of 'asset.dart';

/// A cryptocurrency or blockchain-native asset.
///
/// Unlike other non-fiat assets, a crypto asset may optionally be enabled for
/// direct payments.
///
/// Payment support defaults to disabled because possession or valuation of a
/// crypto asset does not necessarily mean it should appear as a payment
/// instrument.
@MappableClass()
final class CryptoAsset extends Asset with CryptoAssetMappable {
  /// Whether this crypto asset can be used directly for payments.
  ///
  /// Defaults to `false`.
  @override
  final bool paymentEnabled;

  /// Creates a crypto asset.
  CryptoAsset({
    required super.id,
    required super.entityVersion,
    required super.createdAt,
    required super.modifiedAt,
    required super.name,
    required super.code,
    super.symbol,
    super.logo,
    required super.decimalPlaces,
    this.paymentEnabled = false,
  });

  /// Creates a crypto asset with generated identity and audit timestamps.
  factory CryptoAsset.create({
    required String name,
    required AssetCode code,
    String? symbol,
    EntityLogo? logo,
    required int decimalPlaces,
    bool paymentEnabled = false,
    Clock? clock,
  }) {
    final resolvedClock = clock ?? createClock();
    final now = resolvedClock.nowUtc;

    return CryptoAsset(
      id: AssetId.generate(),
      entityVersion: 1,
      createdAt: now,
      modifiedAt: now,
      name: name,
      code: code,
      symbol: symbol,
      logo: logo,
      decimalPlaces: decimalPlaces,
      paymentEnabled: paymentEnabled,
    );
  }
}
