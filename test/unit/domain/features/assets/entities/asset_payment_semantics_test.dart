@Tags(['domain'])
library;

import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_code.dart';
import 'package:test/test.dart';

void main() {
  group('Asset payment semantics', () {
    test('Currency is always payment enabled', () {
      // Given / When
      final currency = Currency(
        id: AssetId.fromString('currency-chf'),
        entityVersion: 1,
        createdAt: DateTime.utc(2026, 1, 1),
        modifiedAt: DateTime.utc(2026, 1, 1),
        name: 'Swiss Franc',
        code: AssetCode('CHF'),
        decimalPlaces: 2,
      );

      // Then
      expect(currency.paymentEnabled, isTrue);
    });

    test('Currency.create is always payment enabled', () {
      // Given
      final clock = FixedClock(DateTime.utc(2026, 9, 20));

      // When
      final currency = Currency.create(
        name: 'Swiss Franc',
        code: AssetCode('CHF'),
        decimalPlaces: 2,
        clock: clock,
      );

      // Then
      expect(currency.paymentEnabled, isTrue);
    });

    test('Asset.create still creates a payment-enabled Currency', () {
      // Given
      final clock = FixedClock(DateTime.utc(2026, 9, 20));

      // When
      final asset = Asset.create(
        name: 'Swiss Franc',
        code: AssetCode('CHF'),
        decimalPlaces: 2,
        clock: clock,
      );

      // Then
      expect(asset, isA<Currency>());
      expect(asset.paymentEnabled, isTrue);
    });

    test('CryptoAsset defaults to payment disabled', () {
      // Given / When
      final crypto = CryptoAsset(
        id: AssetId.fromString('crypto-btc'),
        entityVersion: 1,
        createdAt: DateTime.utc(2026, 1, 1),
        modifiedAt: DateTime.utc(2026, 1, 1),
        name: 'Bitcoin',
        code: AssetCode('BTC'),
        decimalPlaces: 8,
      );

      // Then
      expect(crypto.paymentEnabled, isFalse);
    });

    test('CryptoAsset can explicitly enable payments', () {
      // Given / When
      final crypto = CryptoAsset(
        id: AssetId.fromString('crypto-btc'),
        entityVersion: 1,
        createdAt: DateTime.utc(2026, 1, 1),
        modifiedAt: DateTime.utc(2026, 1, 1),
        name: 'Bitcoin',
        code: AssetCode('BTC'),
        decimalPlaces: 8,
        paymentEnabled: true,
      );

      // Then
      expect(crypto.paymentEnabled, isTrue);
    });

    test('CryptoAsset.create defaults to payment disabled', () {
      // Given
      final clock = FixedClock(DateTime.utc(2026, 9, 20));

      // When
      final crypto = CryptoAsset.create(
        name: 'Bitcoin',
        code: AssetCode('BTC'),
        decimalPlaces: 8,
        clock: clock,
      );

      // Then
      expect(crypto.paymentEnabled, isFalse);
    });

    test('CryptoAsset.create can explicitly enable payments', () {
      // Given
      final clock = FixedClock(DateTime.utc(2026, 9, 20));

      // When
      final crypto = CryptoAsset.create(
        name: 'Bitcoin',
        code: AssetCode('BTC'),
        decimalPlaces: 8,
        paymentEnabled: true,
        clock: clock,
      );

      // Then
      expect(crypto.paymentEnabled, isTrue);
    });

    test('StockAsset is always payment disabled', () {
      // Given / When
      final stock = StockAsset(
        id: AssetId.fromString('stock-nvda'),
        entityVersion: 1,
        createdAt: DateTime.utc(2026, 1, 1),
        modifiedAt: DateTime.utc(2026, 1, 1),
        name: 'NVIDIA Corp',
        code: AssetCode('NVDA'),
        decimalPlaces: 6,
      );

      // Then
      expect(stock.paymentEnabled, isFalse);
    });

    test('StockAsset.create is payment disabled', () {
      // When
      final stock = StockAsset.create(
        name: 'NVIDIA Corp',
        code: AssetCode('NVDA'),
        decimalPlaces: 6,
        clock: FixedClock(DateTime.utc(2026, 9, 20)),
      );

      // Then
      expect(stock.paymentEnabled, isFalse);
    });

    test('CommodityAsset is always payment disabled', () {
      // Given / When
      final commodity = CommodityAsset(
        id: AssetId.fromString('commodity-gold'),
        entityVersion: 1,
        createdAt: DateTime.utc(2026, 1, 1),
        modifiedAt: DateTime.utc(2026, 1, 1),
        name: 'Gold',
        code: AssetCode('XAU'),
        decimalPlaces: 6,
      );

      // Then
      expect(commodity.paymentEnabled, isFalse);
    });

    test('CommodityAsset.create is payment disabled', () {
      // When
      final commodity = CommodityAsset.create(
        name: 'Gold',
        code: AssetCode('XAU'),
        decimalPlaces: 6,
        clock: FixedClock(DateTime.utc(2026, 9, 20)),
      );

      // Then
      expect(commodity.paymentEnabled, isFalse);
    });

    test('CryptoAsset round trips through dart_mappable', () {
      // Given
      final original = CryptoAsset(
        id: AssetId.fromString('crypto-btc'),
        entityVersion: 1,
        createdAt: DateTime.utc(2026, 1, 1),
        modifiedAt: DateTime.utc(2026, 1, 1),
        name: 'Bitcoin',
        code: AssetCode('BTC'),
        decimalPlaces: 8,
        paymentEnabled: true,
      );

      // When
      final rebuilt = CryptoAssetMapper.fromJson(original.toJson());

      // Then
      expect(rebuilt, original);
      expect(rebuilt.paymentEnabled, isTrue);
    });

    test('StockAsset round trips through dart_mappable', () {
      // Given
      final original = StockAsset(
        id: AssetId.fromString('stock-nvda'),
        entityVersion: 1,
        createdAt: DateTime.utc(2026, 1, 1),
        modifiedAt: DateTime.utc(2026, 1, 1),
        name: 'NVIDIA Corp',
        code: AssetCode('NVDA'),
        decimalPlaces: 6,
      );

      // When
      final rebuilt = StockAssetMapper.fromJson(original.toJson());

      // Then
      expect(rebuilt, original);
      expect(rebuilt.paymentEnabled, isFalse);
    });

    test('CommodityAsset round trips through dart_mappable', () {
      // Given
      final original = CommodityAsset(
        id: AssetId.fromString('commodity-gold'),
        entityVersion: 1,
        createdAt: DateTime.utc(2026, 1, 1),
        modifiedAt: DateTime.utc(2026, 1, 1),
        name: 'Gold',
        code: AssetCode('XAU'),
        decimalPlaces: 6,
      );

      // When
      final rebuilt = CommodityAssetMapper.fromJson(original.toJson());

      // Then
      expect(rebuilt, original);
      expect(rebuilt.paymentEnabled, isFalse);
    });
  });
}
