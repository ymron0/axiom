@Tags(['application'])
library;

import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/features/assets/application/commands/create_asset_command.dart';
import 'package:axiom/src/features/assets/application/mappers/create_asset_command_mapper.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_code.dart';
import 'package:test/test.dart';

void main() {
  final clock = FixedClock(DateTime.utc(2026, 9, 20));
  const mapper = CreateAssetCommandMapper();

  test('maps a currency command to Currency', () {
    final command = CreateCurrencyCommand(
      name: 'Swiss Franc',
      code: AssetCode('CHF'),
      symbol: 'CHF',
      decimalPlaces: 2,
    );

    final asset = mapper.toEntity(command: command, clock: clock);

    expect(asset, isA<Currency>());
    expect(asset.name, 'Swiss Franc');
    expect(asset.code.value, 'CHF');
    expect(asset.createdAt, clock.nowUtc);
  });

  test('maps a crypto command and forwards payment eligibility', () {
    final command = CreateCryptoAssetCommand(
      name: 'Bitcoin',
      code: AssetCode('BTC'),
      decimalPlaces: 8,
      paymentEnabled: true,
    );

    final asset = mapper.toEntity(command: command, clock: clock);

    expect(asset, isA<CryptoAsset>());
    expect((asset as CryptoAsset).paymentEnabled, isTrue);
    expect(asset.createdAt, clock.nowUtc);
  });

  test('maps stock and commodity commands to their concrete types', () {
    final stock = mapper.toEntity(
      command: CreateStockAssetCommand(
        name: 'NVIDIA',
        code: AssetCode('NVDA'),
        decimalPlaces: 6,
      ),
      clock: clock,
    );
    final commodity = mapper.toEntity(
      command: CreateCommodityAssetCommand(
        name: 'Gold',
        code: AssetCode('XAU'),
        decimalPlaces: 6,
      ),
      clock: clock,
    );

    expect(stock, isA<StockAsset>());
    expect(commodity, isA<CommodityAsset>());
    expect(stock.createdAt, clock.nowUtc);
    expect(commodity.createdAt, clock.nowUtc);
  });
}
