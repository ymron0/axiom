@Tags(['domain'])
library;

import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_code.dart';
import 'package:test/test.dart';

void main() {
  test('defaults payment eligibility to false', () {
    final asset = CryptoAsset.create(
      name: 'Bitcoin',
      code: AssetCode('BTC'),
      decimalPlaces: 8,
      clock: FixedClock(DateTime.utc(2026, 9, 20)),
    );

    expect(asset.paymentEnabled, isFalse);
    expect(asset.entityVersion, 1);
  });

  test('can enable payments and preserves the setting', () {
    final asset = CryptoAsset.create(
      name: 'Bitcoin',
      code: AssetCode('BTC'),
      decimalPlaces: 8,
      paymentEnabled: true,
      clock: FixedClock(DateTime.utc(2026, 9, 20)),
    );

    expect(asset.paymentEnabled, isTrue);
    expect(asset.code.value, 'BTC');
  });
}
