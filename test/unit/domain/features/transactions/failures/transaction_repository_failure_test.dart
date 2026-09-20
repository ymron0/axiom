import 'package:axiom/src/features/transactions/domain/failures/transaction_repository_failure.dart';
import 'package:test/test.dart';

void main() {
  group('TransactionRepositoryFailure', () {
    test('preserves its diagnostic failure information', () {
      const failure = TransactionRepositoryFailure(
        message: 'repository failed',
      );

      expect(failure.message, 'repository failed');
      expect(failure.type, TransactionRepositoryFailure.typeId);
      expect(failure.failureOrNull, same(failure));
    });
  });
}
