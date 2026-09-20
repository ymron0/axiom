import 'package:axiom/src/application/di/services/validate_category_budget_currencies_service_provider.dart';
import 'package:axiom/src/application/services/update_category_service.dart';
import 'package:axiom/src/features/categories/di/update_category_use_case_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'update_category_service_provider.g.dart';

/// Provides cross-feature Category updates.
@riverpod
UpdateCategoryService updateCategoryService(Ref ref) {
  return UpdateCategoryService(
    validateBudgetCurrencies: ref.watch(
      validateCategoryBudgetCurrenciesServiceProvider,
    ),
    updateCategory: ref.watch(updateCategoryUseCaseProvider),
  );
}
