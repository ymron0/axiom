import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_code.dart';

/// Creates a reusable commodity-asset fixture.
CommodityAsset commodityAssetFixture({
  String id = 'commodity-asset-1',
  String name = 'Gold',
  String code = 'XAU',
  int decimalPlaces = 6,
}) {
  return CommodityAsset(
    id: AssetId.fromString(id),
    entityVersion: 1,
    createdAt: DateTime.utc(2024, 1, 1),
    modifiedAt: DateTime.utc(2024, 1, 1),
    name: name,
    code: AssetCode(code),
    decimalPlaces: decimalPlaces,
  );
}

/// Creates a reusable crypto-asset fixture.
CryptoAsset cryptoAssetFixture({
  String id = 'crypto-asset-1',
  String name = 'Bitcoin',
  String code = 'BTC',
  int decimalPlaces = 8,
  bool paymentEnabled = false,
}) {
  return CryptoAsset(
    id: AssetId.fromString(id),
    entityVersion: 1,
    createdAt: DateTime.utc(2024, 1, 1),
    modifiedAt: DateTime.utc(2024, 1, 1),
    name: name,
    code: AssetCode(code),
    decimalPlaces: decimalPlaces,
    paymentEnabled: paymentEnabled,
  );
}

/// Creates a reusable currency fixture for asset tests.
Currency currencyFixture({
  String id = 'asset-1',
  String name = 'Euro',
  String code = 'EUR',
  int decimalPlaces = 2,
}) {
  return Currency(
    id: AssetId.fromString(id),
    entityVersion: 1,
    createdAt: DateTime.utc(2024, 1, 1),
    modifiedAt: DateTime.utc(2024, 1, 1),
    name: name,
    code: AssetCode(code),
    decimalPlaces: decimalPlaces,
  );
}

/// Creates a reusable stock-asset fixture.
StockAsset stockAssetFixture({
  String id = 'stock-asset-1',
  String name = 'NVIDIA Corp',
  String code = 'NVDA',
  int decimalPlaces = 6,
}) {
  return StockAsset(
    id: AssetId.fromString(id),
    entityVersion: 1,
    createdAt: DateTime.utc(2024, 1, 1),
    modifiedAt: DateTime.utc(2024, 1, 1),
    name: name,
    code: AssetCode(code),
    decimalPlaces: decimalPlaces,
  );
}
