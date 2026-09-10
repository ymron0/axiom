import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_code.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';

/// Creates a reusable currency fixture for asset tests.
///
/// Example: `final euro = currencyFixture();`
Currency currencyFixture({
  String id = 'asset-1',
  String name = 'Euro',
  String code = 'EUR',
}) {
  return Currency(
    id: AssetId.fromString(id),
    name: name,
    code: AssetCode(code),
    decimalPlaces: 2,
  );
}
