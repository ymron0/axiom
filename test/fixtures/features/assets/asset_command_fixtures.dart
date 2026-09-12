import 'package:axiom/src/features/assets/application/commands/create_asset_command.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_code.dart';

/// Creates a reusable asset creation command for tests.
CreateAssetCommand createAssetCommandFixture({
  String name = 'Euro',
  String code = 'EUR',
}) {
  return CreateAssetCommand(
    name: name,
    code: AssetCode(code),
    decimalPlaces: 2,
  );
}
