import 'package:axiom/src/features/transactions/domain/failures/transaction_not_found_failure.dart';
import 'package:test/test.dart';

void main() {
  group('TransactionNotFoundFailure', () {
    test('returns its static type identifier from type', () {
      // Given
      const failure = TransactionNotFoundFailure();

      // Then
      expect(failure.type, TransactionNotFoundFailure.typeId);
    });
  });
}
