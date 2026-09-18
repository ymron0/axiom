@Tags(['domain'])
library;

import 'package:axiom/src/features/transactions/domain/failures/transaction_series_already_exists_failure.dart';
import 'package:test/test.dart';

void main() {
  group('TransactionSeriesAlreadyExistsFailure', () {
    test('exposes its stable failure contract', () {
      const failure = TransactionSeriesAlreadyExistsFailure(
        message: 'Duplicate.',
      );

      expect(failure.message, 'Duplicate.');
      expect(failure.type, TransactionSeriesAlreadyExistsFailure.typeId);
      expect(failure.failureOrNull, same(failure));
    });
  });
}
