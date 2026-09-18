@Tags(['domain'])
library;

import 'package:axiom/src/features/transactions/domain/failures/transaction_series_already_archived_failure.dart';
import 'package:test/test.dart';

void main() {
  group('TransactionSeriesAlreadyArchivedFailure', () {
    test('exposes its stable failure contract', () {
      const failure = TransactionSeriesAlreadyArchivedFailure(
        message: 'Archived.',
      );

      expect(failure.message, 'Archived.');
      expect(failure.type, TransactionSeriesAlreadyArchivedFailure.typeId);
      expect(failure.failureOrNull, same(failure));
    });
  });
}
