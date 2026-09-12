import 'package:axiom/src/features/transactions/domain/failures/transaction_already_exists_failure.dart';
import 'package:test/test.dart';

void main() {
  group('TransactionAlreadyExistsFailure', () {
    test('returns its static type identifier from type', () {
      // Given
      const failure = TransactionAlreadyExistsFailure();

      // Then
      expect(failure.type, TransactionAlreadyExistsFailure.typeId);
    });
  });
}
