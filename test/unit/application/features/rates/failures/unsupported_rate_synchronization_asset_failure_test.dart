@Tags(['application'])
library;

import 'package:axiom/src/features/rates/application/failures/unsupported_rate_synchronization_asset_failure.dart';
import 'package:test/test.dart';

void main() {
  test('exposes its type and itself as the failure', () {
    const failure = UnsupportedRateSynchronizationAssetFailure(
      message: 'unsupported',
    );

    expect(failure.type, UnsupportedRateSynchronizationAssetFailure.typeId);
    expect(failure.failureOrNull, same(failure));
    expect(failure.message, 'unsupported');
  });
}
