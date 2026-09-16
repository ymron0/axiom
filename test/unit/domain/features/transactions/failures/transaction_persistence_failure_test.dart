@Tags(['domain'])
library;

import 'package:axiom/src/features/transactions/data/failures/transaction_persistence_failure.dart';
import 'package:test/test.dart';

void main() {
  group('TransactionPersistenceFailure', () {
    test('can be instantiated without a diagnostic message', () {
      // Given
      const failure = TransactionPersistenceFailure();

      // Then
      expect(failure.message, isNull);
    });

    test('preserves the provided diagnostic message', () {
      // Given
      const message = 'Transaction persistence failed.';

      // When
      const failure = TransactionPersistenceFailure(message: message);

      // Then
      expect(failure.message, message);
    });

    test('returns its static type identifier from type', () {
      // Given
      const failure = TransactionPersistenceFailure();

      // Then
      expect(failure.type, TransactionPersistenceFailure.typeId);
    });

    test('returns itself from failureOrNull', () {
      // Given
      const failure = TransactionPersistenceFailure();

      // Then
      expect(failure.failureOrNull, same(failure));
    });
  });
}
