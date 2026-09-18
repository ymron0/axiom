@Tags(['domain'])
library;

import 'package:axiom/src/features/transactions/domain/failures/transaction_series_not_archived_failure.dart';
import 'package:test/test.dart';

void main() {
  group('TransactionSeriesNotArchivedFailure', () {
    test('exposes its stable failure contract', () {
      const failure = TransactionSeriesNotArchivedFailure(
        message: 'Not archived.',
      );

      expect(failure.message, 'Not archived.');
      expect(failure.type, TransactionSeriesNotArchivedFailure.typeId);
      expect(failure.failureOrNull, same(failure));
    });
  });
}
