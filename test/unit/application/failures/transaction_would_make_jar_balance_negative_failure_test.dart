@Tags(['application'])
library;

import 'package:axiom/src/application/failures/transaction_would_make_jar_balance_negative_failure.dart';
import 'package:test/test.dart';

void main() {
  group('TransactionWouldMakeJarBalanceNegativeFailure', () {
    test('preserves its message and returns both typed getters', () {
      // Given
      const failure = TransactionWouldMakeJarBalanceNegativeFailure(
        message: 'Transaction would make jar balance negative.',
      );

      // Then
      expect(
        failure.message,
        'Transaction would make jar balance negative.',
      );
      expect(failure.failureOrNull, same(failure));
      expect(
        failure.type,
        TransactionWouldMakeJarBalanceNegativeFailure.typeId,
      );
    });
  });
}

