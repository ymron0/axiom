@Tags(['domain'])
library;

import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_code.dart';
import 'package:test/test.dart';

void main() {
  test('creates a non-payment commodity with deterministic metadata', () {
    final commodity = CommodityAsset.create(
      name: ' Gold ',
      code: AssetCode('XAU'),
      decimalPlaces: 6,
      clock: FixedClock(DateTime.utc(2026, 9, 20)),
    );

    expect(commodity.id.value, isNotEmpty);
    expect(commodity.name, 'Gold');
    expect(commodity.createdAt, DateTime.utc(2026, 9, 20));
    expect(commodity.modifiedAt, commodity.createdAt);
    expect(commodity.paymentEnabled, isFalse);
  });

  test('preserves supplied identity and metadata', () {
    final id = AssetId.fromString('gold');
    final commodity = CommodityAsset(
      id: id,
      entityVersion: 1,
      createdAt: DateTime.utc(2026),
      modifiedAt: DateTime.utc(2026),
      name: 'Gold',
      code: AssetCode('XAU'),
      decimalPlaces: 6,
    );

    expect(commodity.id, id);
    expect(commodity.code.value, 'XAU');
    expect(commodity.decimalPlaces, 6);
    expect(commodity.paymentEnabled, isFalse);
  });
}
