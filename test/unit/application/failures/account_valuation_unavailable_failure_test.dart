@Tags(['application'])
library;

import 'package:axiom/src/application/failures/account_valuation_unavailable_failure.dart';
import 'package:test/test.dart';

void main() {
  test('exposes its type and itself as the failure', () {
    const failure = AccountValuationUnavailableFailure(message: 'unavailable');

    expect(failure.type, AccountValuationUnavailableFailure.typeId);
    expect(failure.failureOrNull, same(failure));
    expect(failure.message, 'unavailable');
  });
}
