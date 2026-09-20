import 'package:axiom/src/application/services/validate_category_budget_currencies_service.dart';
import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/categories/application/use_cases/update_category_use_case.dart';
import 'package:axiom/src/features/categories/domain/entities/category.dart';

/// Coordinates cross-feature validation before updating a Category.
final class UpdateCategoryService {
  final ValidateCategoryBudgetCurrenciesService _validateBudgetCurrencies;

  final UpdateCategoryUseCase _updateCategory;
  /// Creates the orchestration service.
  const UpdateCategoryService({
    required ValidateCategoryBudgetCurrenciesService validateBudgetCurrencies,
    required UpdateCategoryUseCase updateCategory,
  }) : _validateBudgetCurrencies = // ignore: prefer_initializing_formals
           validateBudgetCurrencies,
       _updateCategory = updateCategory; // ignore: prefer_initializing_formals

  /// Validates all budget currencies and persists [category].
  Future<Result<void, BaseFailure>> call(Category category) async {
    final validationResult = await _validateBudgetCurrencies(category.budgets);

    if (validationResult case final Failure<BaseFailure> failure) {
      return failure;
    }

    return _updateCategory(category);
  }
}
