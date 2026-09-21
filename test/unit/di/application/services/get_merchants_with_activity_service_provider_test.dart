@Tags(['di'])
library;

import 'package:axiom/src/application/di/services/get_merchants_with_activity_service_provider.dart';
import 'package:axiom/src/application/services/get_merchants_with_activity_service.dart';
import 'package:axiom/src/features/merchants/application/use_cases/get_merchants_use_case.dart';
import 'package:axiom/src/features/merchants/di/get_merchants_use_case_provider.dart';
import 'package:axiom/src/features/transactions/application/use_cases/query_transactions_use_case.dart';
import 'package:axiom/src/features/transactions/di/query_transactions_use_case_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:test/test.dart';

import '../../../../mocks/merchant_repository_mock.dart';
import '../../../../mocks/transaction_repository_mock.dart';

void main() {
  group('getMerchantsWithActivityService provider', () {
    test('resolves the merchant activity service', () {
      final container = ProviderContainer(
        overrides: [
          queryTransactionsUseCaseProvider.overrideWithValue(
            QueryTransactionsUseCase(MockTransactionRepository()),
          ),
          getMerchantsUseCaseProvider.overrideWithValue(
            GetMerchantsUseCase(MockMerchantRepository()),
          ),
        ],
      );

      addTearDown(container.dispose);

      final service = container.read(getMerchantsWithActivityServiceProvider);

      expect(service, isA<GetMerchantsWithActivityService>());
    });
  });
}
