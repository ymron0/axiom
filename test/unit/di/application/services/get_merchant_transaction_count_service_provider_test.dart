@Tags(['di'])
library;

import 'package:axiom/src/application/di/services/get_merchant_transaction_count_service_provider.dart';
import 'package:axiom/src/application/services/get_merchant_transaction_count_service.dart';
import 'package:axiom/src/features/transactions/application/use_cases/query_transactions_use_case.dart';
import 'package:axiom/src/features/transactions/di/query_transactions_use_case_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:test/test.dart';

import '../../../../mocks/transaction_repository_mock.dart';

void main() {
  group('getMerchantTransactionCountService provider', () {
    test('resolves the merchant transaction-count service', () {
      final container = ProviderContainer(
        overrides: [
          queryTransactionsUseCaseProvider.overrideWithValue(
            QueryTransactionsUseCase(MockTransactionRepository()),
          ),
        ],
      );
      addTearDown(container.dispose);

      final service = container.read(
        getMerchantTransactionCountServiceProvider,
      );

      expect(service, isA<GetMerchantTransactionCountService>());
    });
  });
}
