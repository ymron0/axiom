import 'package:axiom/src/application/di/services/validate_category_budget_currencies_service_provider.dart';
import 'package:axiom/src/application/services/create_category_service.dart';
import 'package:axiom/src/features/categories/di/create_category_use_case_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'create_category_service_provider.g.dart';

/// Provides cross-feature Category creation.
@riverpod
CreateCategoryService createCategoryService(Ref ref) {
  return CreateCategoryService(
    validateBudgetCurrencies: ref.watch(
      validateCategoryBudgetCurrenciesServiceProvider,
    ),
    createCategory: ref.watch(createCategoryUseCaseProvider),
  );
}
