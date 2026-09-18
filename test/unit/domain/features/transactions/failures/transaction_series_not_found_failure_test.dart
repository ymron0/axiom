@Tags(['domain'])
library;

import 'package:axiom/src/features/transactions/domain/failures/transaction_series_not_found_failure.dart';
import 'package:test/test.dart';

void main() {
  group('TransactionSeriesNotFoundFailure', () {
    test('exposes its stable failure contract', () {
      const failure = TransactionSeriesNotFoundFailure(message: 'Missing.');

      expect(failure.message, 'Missing.');
      expect(failure.type, TransactionSeriesNotFoundFailure.typeId);
      expect(failure.failureOrNull, same(failure));
    });
  });
}
