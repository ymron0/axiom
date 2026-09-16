@Tags(['application', 'di'])
library;

import 'package:axiom/src/application/di/services/delete_category_service_provider.dart';
import 'package:axiom/src/application/services/delete_category_service.dart';
import 'package:axiom/src/features/categories/application/use_cases/delete_category_use_case.dart';
import 'package:axiom/src/features/categories/application/use_cases/get_categories_use_case.dart';
import 'package:axiom/src/features/categories/application/use_cases/get_category_by_id_use_case.dart';
import 'package:axiom/src/features/categories/di/delete_category_use_case_provider.dart';
import 'package:axiom/src/features/categories/di/get_categories_use_case_provider.dart';
import 'package:axiom/src/features/categories/di/get_category_by_id_use_case_provider.dart';
import 'package:axiom/src/features/transactions/application/use_cases/transactions_exist_by_category_id_use_case.dart';
import 'package:axiom/src/features/transactions/di/transactions_exist_by_category_id_use_case_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:test/test.dart';

import '../../../../../mocks/category_repository_mock.dart';
import '../../../../../mocks/transaction_repository_mock.dart';

void main() {
  group('deleteCategoryServiceProvider', () {
    test('provides the category deletion service', () {
      final container = ProviderContainer(
        overrides: [
          getCategoryByIdUseCaseProvider.overrideWithValue(
            GetCategoryByIdUseCase(MockCategoryRepository()),
          ),
          getCategoriesUseCaseProvider.overrideWithValue(
            GetCategoriesUseCase(MockCategoryRepository()),
          ),
          transactionsExistByCategoryIdUseCaseProvider.overrideWithValue(
            TransactionsExistByCategoryIdUseCase(MockTransactionRepository()),
          ),
          deleteCategoryUseCaseProvider.overrideWithValue(
            DeleteCategoryUseCase(MockCategoryRepository()),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(deleteCategoryServiceProvider), isA<DeleteCategoryService>());
    });
  });
}
