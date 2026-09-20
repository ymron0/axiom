@Tags(['application'])
library;

import 'package:axiom/src/features/assets/application/commands/create_asset_command.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_code.dart';
import 'package:test/test.dart';

void main() {
  test('stores the common creation fields', () {
    final command = CreateStockAssetCommand(
      name: 'NVIDIA',
      code: AssetCode('NVDA'),
      symbol: 'NVDA',
      decimalPlaces: 6,
    );

    expect(command, isA<CreateAssetCommand>());
    expect(command.name, 'NVIDIA');
    expect(command.code.value, 'NVDA');
    expect(command.symbol, 'NVDA');
    expect(command.decimalPlaces, 6);
  });
}
