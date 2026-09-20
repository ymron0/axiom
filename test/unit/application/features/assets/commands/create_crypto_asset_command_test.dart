@Tags(['application'])
library;

import 'package:axiom/src/features/assets/application/commands/create_asset_command.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_code.dart';
import 'package:test/test.dart';

void main() {
  test('defaults payment eligibility to false', () {
    final command = CreateCryptoAssetCommand(
      name: 'Bitcoin',
      code: AssetCode('BTC'),
      decimalPlaces: 8,
    );

    expect(command, isA<CreateAssetCommand>());
    expect(command.paymentEnabled, isFalse);
  });

  test('stores explicit payment eligibility', () {
    final command = CreateCryptoAssetCommand(
      name: 'Bitcoin',
      code: AssetCode('BTC'),
      decimalPlaces: 8,
      paymentEnabled: true,
    );

    expect(command.paymentEnabled, isTrue);
  });
}
