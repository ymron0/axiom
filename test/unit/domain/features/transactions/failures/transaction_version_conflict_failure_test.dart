import 'package:axiom/src/features/transactions/domain/failures/transaction_version_conflict_failure.dart';
import 'package:test/test.dart';

void main() {
  group('TransactionVersionConflictFailure', () {
    test('returns its static type identifier from type', () {
      // Given
      const failure = TransactionVersionConflictFailure();

      // Then
      expect(failure.type, TransactionVersionConflictFailure.typeId);
    });
  });
}
