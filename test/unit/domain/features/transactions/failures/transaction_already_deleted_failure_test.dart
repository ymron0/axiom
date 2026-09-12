import 'package:axiom/src/features/transactions/domain/failures/transaction_already_deleted_failure.dart';
import 'package:test/test.dart';

void main() {
  group('TransactionAlreadyDeletedFailure', () {
    test('returns its static type identifier from type', () {
      // Given
      const failure = TransactionAlreadyDeletedFailure();

      // Then
      expect(failure.type, TransactionAlreadyDeletedFailure.typeId);
    });
  });
}
