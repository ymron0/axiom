@Tags(['application', 'di'])
library;

import 'package:axiom/src/application/di/services/validate_transaction_budgets_service_provider.dart';
import 'package:axiom/src/application/services/validate_transaction_budgets_service.dart';
import 'package:axiom/src/features/categories/di/get_categories_use_case_provider.dart';
import 'package:axiom/src/features/settings/di/get_settings_use_case_provider.dart';
import 'package:axiom/src/features/transactions/di/query_transactions_use_case_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:test/test.dart';

import '../../../../mocks/get_categories_use_case_mock.dart';
import '../../../../mocks/get_settings_use_case_mock.dart';
import '../../../../mocks/query_transactions_use_case_mock.dart';

void main() {
  group('validateTransactionBudgetsServiceProvider', () {
    test('provides the configured budget validator', () {
      final container = ProviderContainer(
        overrides: [
          getSettingsUseCaseProvider.overrideWithValue(
            MockGetSettingsUseCase(),
          ),
          getCategoriesUseCaseProvider.overrideWithValue(
            MockGetCategoriesUseCase(),
          ),
          queryTransactionsUseCaseProvider.overrideWithValue(
            MockQueryTransactionsUseCase(),
          ),
        ],
      );

      addTearDown(container.dispose);

      expect(
        container.read(validateTransactionBudgetsServiceProvider),
        isA<ValidateTransactionBudgetsService>(),
      );
    });
  });
}
