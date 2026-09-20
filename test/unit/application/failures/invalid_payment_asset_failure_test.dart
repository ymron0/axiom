@Tags(['application'])
library;

import 'package:axiom/src/application/failures/invalid_payment_asset_failure.dart';
import 'package:test/test.dart';

void main() {
  test('exposes its type and itself as the failure', () {
    const failure = InvalidPaymentAssetFailure(message: 'not payable');

    expect(failure.type, InvalidPaymentAssetFailure.typeId);
    expect(failure.failureOrNull, same(failure));
    expect(failure.message, 'not payable');
  });
}
