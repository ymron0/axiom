@Tags(['application'])
library;

import 'package:axiom/src/application/failures/transaction_occurrence_operation_failure.dart';
import 'package:test/test.dart';

void main() {
  group('TransactionOccurrenceOperationFailure', () {
    test('preserves its message and returns both typed getters', () {
      // Given
      const failure = TransactionOccurrenceOperationFailure(
        message: 'Transaction is not a generated recurrence occurrence.',
      );

      // Then
      expect(
        failure.message,
        'Transaction is not a generated recurrence occurrence.',
      );
      expect(failure.failureOrNull, same(failure));
      expect(failure.type, TransactionOccurrenceOperationFailure.typeId);
      expect(
        TransactionOccurrenceOperationFailure.typeId,
        'application.transactionOccurrenceOperation',
      );
    });

    test('supports value equality', () {
      // Given
      const failure1 = TransactionOccurrenceOperationFailure(
        message: 'Cannot delete occurrence.',
      );
      const failure2 = TransactionOccurrenceOperationFailure(
        message: 'Cannot delete occurrence.',
      );
      const different = TransactionOccurrenceOperationFailure(
        message: 'Different error.',
      );

      // Then
      expect(failure1, equals(failure2));
      expect(failure1.hashCode, equals(failure2.hashCode));
      expect(failure1, isNot(equals(different)));
    });
  });
}
