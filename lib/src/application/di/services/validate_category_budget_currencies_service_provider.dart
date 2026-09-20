import 'package:axiom/src/application/di/services/get_valuation_currency_service_provider.dart';
import 'package:axiom/src/application/services/validate_category_budget_currencies_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'validate_category_budget_currencies_service_provider.g.dart';

/// Provides Category budget currency validation.
@riverpod
ValidateCategoryBudgetCurrenciesService validateCategoryBudgetCurrenciesService(
  Ref ref,
) {
  return ValidateCategoryBudgetCurrenciesService(
    getValuationCurrency: ref.watch(getValuationCurrencyServiceProvider),
  );
}
