@Tags(['domain'])
library;

import 'package:axiom/src/features/transactions/domain/failures/transaction_offset_validation_failure.dart';
import 'package:test/test.dart';

void main() {
  group('TransactionOffsetValidationFailure', () {
    test('returns its static type identifier from type', () {
      const failure = TransactionOffsetValidationFailure();

      expect(failure.type, TransactionOffsetValidationFailure.typeId);
    });
  });
}
