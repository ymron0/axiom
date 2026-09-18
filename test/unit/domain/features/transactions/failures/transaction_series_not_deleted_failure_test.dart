@Tags(['domain'])
library;

import 'package:axiom/src/features/transactions/domain/failures/transaction_series_not_deleted_failure.dart';
import 'package:test/test.dart';

void main() {
  group('TransactionSeriesNotDeletedFailure', () {
    test('exposes its stable failure contract', () {
      const failure = TransactionSeriesNotDeletedFailure(
        message: 'Not deleted.',
      );

      expect(failure.message, 'Not deleted.');
      expect(failure.type, TransactionSeriesNotDeletedFailure.typeId);
      expect(failure.failureOrNull, same(failure));
    });
  });
}
