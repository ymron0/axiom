@Tags(['application'])
library;

import 'package:axiom/src/application/failures/transaction_would_exceed_budget_failure.dart';
import 'package:test/test.dart';

void main() {
  group('TransactionWouldExceedBudgetFailure', () {
    test('preserves its message and returns both typed getters', () {
      // Given
      const failure = TransactionWouldExceedBudgetFailure(
        message: 'Transaction would exceed budget.',
      );

      // Then
      expect(failure.message, 'Transaction would exceed budget.');
      expect(failure.failureOrNull, same(failure));
      expect(failure.type, TransactionWouldExceedBudgetFailure.typeId);
    });
  });
}
