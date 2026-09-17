@Tags(['di'])
library;

import 'package:axiom/src/application/di/services/get_category_spending_service_provider.dart';
import 'package:axiom/src/application/services/get_category_spending_service.dart';
import 'package:axiom/src/features/categories/application/use_cases/get_categories_use_case.dart';
import 'package:axiom/src/features/categories/application/use_cases/get_category_by_id_use_case.dart';
import 'package:axiom/src/features/categories/di/get_categories_use_case_provider.dart';
import 'package:axiom/src/features/categories/di/get_category_by_id_use_case_provider.dart';
import 'package:axiom/src/features/settings/application/use_cases/get_settings_use_case.dart';
import 'package:axiom/src/features/settings/di/get_settings_use_case_provider.dart';
import 'package:axiom/src/features/transactions/application/use_cases/query_transactions_use_case.dart';
import 'package:axiom/src/features/transactions/di/query_transactions_use_case_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:test/test.dart';

import '../../../../mocks/category_repository_mock.dart';
import '../../../../mocks/settings_repository_mock.dart';
import '../../../../mocks/transaction_repository_mock.dart';

void main() {
  group('getCategorySpendingService provider', () {
    test('resolves the category spending service', () {
      final container = ProviderContainer(
        overrides: [
          getCategoryByIdUseCaseProvider.overrideWithValue(
            GetCategoryByIdUseCase(MockCategoryRepository()),
          ),
          getCategoriesUseCaseProvider.overrideWithValue(
            GetCategoriesUseCase(MockCategoryRepository()),
          ),
          getSettingsUseCaseProvider.overrideWithValue(
            GetSettingsUseCase(MockSettingsRepository()),
          ),
          queryTransactionsUseCaseProvider.overrideWithValue(
            QueryTransactionsUseCase(MockTransactionRepository()),
          ),
        ],
      );
      addTearDown(container.dispose);

      final service = container.read(getCategorySpendingServiceProvider);

      expect(service, isA<GetCategorySpendingService>());
    });
  });
}
