@Tags(['data', 'persistence'])
library;

import 'package:axiom/src/features/assets/data/repositories/sembast_asset_repository_impl.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/assets/domain/repositories/asset_repository.dart';
import 'package:sembast/sembast.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/core/persistence/persistence_test_environment.dart';
import '../../../../../fixtures/features/assets/asset_fixtures.dart';

void main() {
  late Database database;
  late AssetRepository repository;

  setUp(() async {
    final sembastDatabase = await createTestSembastDatabase();
    database = await sembastDatabase.open();

    repository = SembastAssetRepositoryImpl(database: database);
  });

  group('SembastAssetRepositoryImpl asset subtypes', () {
    test('persists and reconstructs every supported asset subtype', () async {
      // Given
      final currency = currencyFixture(
        id: 'currency-chf',
        name: 'Swiss Franc',
        code: 'CHF',
      );
      final crypto = cryptoAssetFixture(
        id: 'crypto-btc',
        name: 'Bitcoin',
        code: 'BTC',
        paymentEnabled: true,
      );
      final stock = stockAssetFixture(
        id: 'stock-nvda',
        name: 'NVIDIA Corp',
        code: 'NVDA',
      );
      final commodity = commodityAssetFixture(
        id: 'commodity-xau',
        name: 'Gold',
        code: 'XAU',
      );

      // When
      final createResult = await repository.createAll([
        currency,
        crypto,
        stock,
        commodity,
      ]);

      // Then
      expect(createResult.isSuccess, isTrue);

      final storedCurrency = (await repository.getById(
        currency.id,
      )).valueOrNull;
      final storedCrypto = (await repository.getById(crypto.id)).valueOrNull;
      final storedStock = (await repository.getById(stock.id)).valueOrNull;
      final storedCommodity = (await repository.getById(
        commodity.id,
      )).valueOrNull;

      expect(storedCurrency, isA<Currency>());
      expect(storedCurrency?.paymentEnabled, isTrue);

      expect(storedCrypto, isA<CryptoAsset>());
      expect(storedCrypto?.paymentEnabled, isTrue);

      expect(storedStock, isA<StockAsset>());
      expect(storedStock?.paymentEnabled, isFalse);

      expect(storedCommodity, isA<CommodityAsset>());
      expect(storedCommodity?.paymentEnabled, isFalse);
    });

    test(
      'persists a CryptoAsset payment-enabled change through update',
      () async {
        // Given
        final original = cryptoAssetFixture(
          id: 'crypto-btc',
          paymentEnabled: false,
        );

        await repository.create(original);

        final updated = CryptoAsset(
          id: original.id,
          entityVersion: original.entityVersion,
          createdAt: original.createdAt,
          modifiedAt: original.modifiedAt,
          name: original.name,
          code: original.code,
          symbol: original.symbol,
          decimalPlaces: original.decimalPlaces,
          logo: original.logo,
          paymentEnabled: true,
        );

        // When
        final result = await repository.update(updated);

        // Then
        expect(result.isSuccess, isTrue);

        final restored = (await repository.getById(original.id)).valueOrNull;

        expect(restored, isA<CryptoAsset>());
        expect(restored?.paymentEnabled, isTrue);
      },
    );
  });
}
