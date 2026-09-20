import 'package:axiom/src/application/services/validate_transaction_budgets_service.dart';
import 'package:axiom/src/features/categories/di/get_categories_use_case_provider.dart';
import 'package:axiom/src/features/categories/domain/services/category_spending_calculator.dart';
import 'package:axiom/src/features/settings/di/get_settings_use_case_provider.dart';
import 'package:axiom/src/features/transactions/di/query_transactions_use_case_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'validate_transaction_budgets_service_provider.g.dart';

/// Provides configurable transaction budget validation.
@riverpod
ValidateTransactionBudgetsService validateTransactionBudgetsService(Ref ref) {
  return ValidateTransactionBudgetsService(
    getSettings: ref.watch(getSettingsUseCaseProvider),
    getCategories: ref.watch(getCategoriesUseCaseProvider),
    queryTransactions: ref.watch(queryTransactionsUseCaseProvider),
    calculator: const CategorySpendingCalculator(),
  );
}
