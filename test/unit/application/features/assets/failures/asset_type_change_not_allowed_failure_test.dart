@Tags(['application'])
library;

import 'package:axiom/src/features/assets/application/failures/asset_type_change_not_allowed_failure.dart';
import 'package:test/test.dart';

void main() {
  test('exposes its type and itself as the failure', () {
    const failure = AssetTypeChangeNotAllowedFailure(message: 'type changed');

    expect(failure.type, AssetTypeChangeNotAllowedFailure.typeId);
    expect(failure.failureOrNull, same(failure));
    expect(failure.message, 'type changed');
  });
}
