@Tags(['application', 'di'])
library;

import 'package:axiom/src/features/transactions/application/use_cases/get_transactions_by_tag_id_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/transactions_exist_by_tag_id_use_case.dart';
import 'package:axiom/src/features/transactions/di/get_transactions_by_tag_id_use_case_provider.dart';
import 'package:axiom/src/features/transactions/di/transaction_repository_provider.dart';
import 'package:axiom/src/features/transactions/di/transactions_exist_by_tag_id_use_case_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:test/test.dart';

import '../../../../../mocks/transaction_repository_mock.dart';

void main() {
  group('transaction tag use-case providers', () {
    test('provide transaction tag queries', () {
      final repository = MockTransactionRepository();

      final container = ProviderContainer(
        overrides: [
          transactionRepositoryProvider.overrideWithValue(repository),
        ],
      );

      addTearDown(container.dispose);

      expect(
        container.read(getTransactionsByTagIdUseCaseProvider),
        isA<GetTransactionsByTagIdUseCase>(),
      );

      expect(
        container.read(transactionsExistByTagIdUseCaseProvider),
        isA<TransactionsExistByTagIdUseCase>(),
      );
    });
  });
}
