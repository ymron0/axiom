@Tags(['domain'])
library;

import 'package:axiom/src/features/transactions/domain/failures/transaction_offset_exceeds_available_amount_failure.dart';
import 'package:test/test.dart';

void main() {
  group('TransactionOffsetExceedsAvailableAmountFailure', () {
    test('returns its static type identifier from type', () {
      const failure = TransactionOffsetExceedsAvailableAmountFailure();

      expect(
        failure.type,
        TransactionOffsetExceedsAvailableAmountFailure.typeId,
      );
    });
  });
}
