@Tags(['application'])
library;

import 'package:axiom/src/features/assets/application/commands/create_asset_command.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_code.dart';
import 'package:test/test.dart';

void main() {
  test('stores the common creation fields', () {
    final command = CreateCommodityAssetCommand(
      name: 'Gold',
      code: AssetCode('XAU'),
      symbol: 'Au',
      logo: null,
      decimalPlaces: 6,
    );

    expect(command, isA<CreateAssetCommand>());
    expect(command.name, 'Gold');
    expect(command.code.value, 'XAU');
    expect(command.symbol, 'Au');
    expect(command.decimalPlaces, 6);
  });
}
