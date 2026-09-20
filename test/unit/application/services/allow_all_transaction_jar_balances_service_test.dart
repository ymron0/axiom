@Tags(['application'])
library;

import 'package:axiom/src/core/result/result.dart';
import 'package:test/test.dart';

import '../../../fixtures/application/services/allow_all_transaction_jar_balances_service.dart';
import '../../../fixtures/features/transactions/transaction_fixtures.dart';

void main() {
  group('AllowAllTransactionJarBalancesService', () {
    test('returns Success without checking transactions', () async {
      // Given
      const service = AllowAllTransactionJarBalancesService();
      final transaction = transactionFixture(id: 'tx-1');
      final previous = transactionFixture(id: 'tx-previous');

      // When
      final resultWithoutPrevious = await service(transaction);
      final resultWithPrevious = await service(transaction, previous: previous);

      // Then
      expect(resultWithoutPrevious, const Success<void>(null));
      expect(resultWithPrevious, const Success<void>(null));
    });
  });
}
