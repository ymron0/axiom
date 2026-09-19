@Tags(['domain'])
library;

import 'package:axiom/src/features/transactions/domain/failures/transaction_series_generation_disabled_failure.dart';
import 'package:test/test.dart';

void main() {
  group('TransactionSeriesGenerationDisabledFailure', () {
    test('returns its static type identifier from type', () {
      // Given
      const failure = TransactionSeriesGenerationDisabledFailure();

      // Then
      expect(failure.type, TransactionSeriesGenerationDisabledFailure.typeId);
    });
  });
}
