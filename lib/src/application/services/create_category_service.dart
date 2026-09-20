import 'package:axiom/src/application/services/validate_category_budget_currencies_service.dart';
import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/categories/application/commands/create_category_command.dart';
import 'package:axiom/src/features/categories/application/use_cases/create_category_use_case.dart';
import 'package:axiom/src/features/categories/domain/entities/category.dart';

/// Coordinates cross-feature validation before creating a Category.
final class CreateCategoryService {
  final ValidateCategoryBudgetCurrenciesService _validateBudgetCurrencies;

  final CreateCategoryUseCase _createCategory;
  /// Creates the orchestration service.
  const CreateCategoryService({
    required ValidateCategoryBudgetCurrenciesService validateBudgetCurrencies,
    required CreateCategoryUseCase createCategory,
  }) : _validateBudgetCurrencies = // ignore: prefer_initializing_formals
           validateBudgetCurrencies,
       _createCategory = createCategory; // ignore: prefer_initializing_formals

  /// Validates budget currencies and creates the category.
  Future<Result<Category, BaseFailure>> call(
    CreateCategoryCommand command,
  ) async {
    final validationResult = await _validateBudgetCurrencies(command.budgets);

    if (validationResult case final Failure<BaseFailure> failure) {
      return failure;
    }

    final createResult = await _createCategory(command);

    return createResult.when<Result<Category, BaseFailure>>(
      success: Success.new,
      failure: (failure) => failure,
    );
  }
}
