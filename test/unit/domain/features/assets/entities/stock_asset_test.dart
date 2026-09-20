@Tags(['domain'])
library;

import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_code.dart';
import 'package:test/test.dart';

void main() {
  test('creates a non-payment stock with deterministic metadata', () {
    final stock = StockAsset.create(
      name: ' NVIDIA ',
      code: AssetCode('NVDA'),
      symbol: ' NVDA ',
      decimalPlaces: 6,
      clock: FixedClock(DateTime.utc(2026, 9, 20)),
    );

    expect(stock.name, 'NVIDIA');
    expect(stock.symbol, 'NVDA');
    expect(stock.createdAt, DateTime.utc(2026, 9, 20));
    expect(stock.paymentEnabled, isFalse);
  });

  test('preserves the stock code and precision', () {
    final stock = StockAsset.create(
      name: 'NVIDIA',
      code: AssetCode('NVDA'),
      decimalPlaces: 6,
      clock: FixedClock(DateTime.utc(2026, 9, 20)),
    );

    expect(stock.code.value, 'NVDA');
    expect(stock.decimalPlaces, 6);
    expect(stock.paymentEnabled, isFalse);
  });
}
