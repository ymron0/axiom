import 'package:axiom/src/application/services/get_category_spending_service.dart';
import 'package:axiom/src/features/categories/di/get_categories_use_case_provider.dart';
import 'package:axiom/src/features/categories/di/get_category_by_id_use_case_provider.dart';
import 'package:axiom/src/features/categories/domain/services/category_spending_calculator.dart';
import 'package:axiom/src/features/settings/di/get_settings_use_case_provider.dart';
import 'package:axiom/src/features/transactions/di/query_transactions_use_case_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'get_category_spending_service_provider.g.dart';

/// Provides the service that derives category activity for a period.
///
/// Cross-feature dependencies remain behind their feature-owned use-case
/// providers. Deterministic monetary aggregation remains owned by the
/// stateless [CategorySpendingCalculator].
@riverpod
GetCategorySpendingService getCategorySpendingService(Ref ref) {
  return GetCategorySpendingService(
    getCategoryById: ref.watch(getCategoryByIdUseCaseProvider),
    getCategories: ref.watch(getCategoriesUseCaseProvider),
    getSettings: ref.watch(getSettingsUseCaseProvider),
    queryTransactions: ref.watch(queryTransactionsUseCaseProvider),
    calculator: const CategorySpendingCalculator(),
  );
}
