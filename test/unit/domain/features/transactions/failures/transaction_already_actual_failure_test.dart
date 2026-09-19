@Tags(['domain'])
library;

import 'package:axiom/src/features/transactions/domain/failures/transaction_already_actual_failure.dart';
import 'package:test/test.dart';

void main() {
  group('TransactionAlreadyActualFailure', () {
    test('returns its static type identifier from type', () {
      // Given
      const failure = TransactionAlreadyActualFailure();

      // Then
      expect(failure.type, TransactionAlreadyActualFailure.typeId);
    });
  });
}
