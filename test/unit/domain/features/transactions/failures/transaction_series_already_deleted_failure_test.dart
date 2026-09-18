@Tags(['domain'])
library;

import 'package:axiom/src/features/transactions/domain/failures/transaction_series_already_deleted_failure.dart';
import 'package:test/test.dart';

void main() {
  group('TransactionSeriesAlreadyDeletedFailure', () {
    test('exposes its stable failure contract', () {
      const failure = TransactionSeriesAlreadyDeletedFailure(
        message: 'Deleted.',
      );

      expect(failure.message, 'Deleted.');
      expect(failure.type, TransactionSeriesAlreadyDeletedFailure.typeId);
      expect(failure.failureOrNull, same(failure));
    });
  });
}
