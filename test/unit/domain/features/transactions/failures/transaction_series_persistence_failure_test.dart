@Tags(['domain'])
library;

import 'package:axiom/src/features/transactions/data/failures/transaction_series_persistence_failure.dart';
import 'package:test/test.dart';

void main() {
  group('TransactionSeriesPersistenceFailure', () {
    test('exposes its stable failure contract', () {
      const failure = TransactionSeriesPersistenceFailure(
        message: 'Persistence failed.',
      );

      expect(failure.message, 'Persistence failed.');
      expect(failure.type, TransactionSeriesPersistenceFailure.typeId);
      expect(failure.failureOrNull, same(failure));
    });

    test('supports an omitted diagnostic message', () {
      const failure = TransactionSeriesPersistenceFailure();

      expect(failure.message, isNull);
    });
  });
}
