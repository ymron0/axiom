import 'package:axiom/src/features/transactions/domain/failures/transaction_not_deleted_failure.dart';
import 'package:test/test.dart';

void main() {
  group('TransactionNotDeletedFailure', () {
    test('returns its static type identifier from type', () {
      // Given
      const failure = TransactionNotDeletedFailure();

      // Then
      expect(failure.type, TransactionNotDeletedFailure.typeId);
    });
  });
}
