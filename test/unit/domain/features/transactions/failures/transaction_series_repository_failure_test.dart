import 'package:axiom/src/features/transactions/domain/failures/transaction_series_repository_failure.dart';
import 'package:test/test.dart';

void main() {
  group('TransactionSeriesRepositoryFailure', () {
    test('preserves its diagnostic failure information', () {
      const failure = TransactionSeriesRepositoryFailure(
        message: 'repository failed',
      );

      expect(failure.message, 'repository failed');
      expect(failure.type, TransactionSeriesRepositoryFailure.typeId);
      expect(failure.failureOrNull, same(failure));
    });
  });
}
