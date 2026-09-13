import 'package:axiom/src/application/services/delete_category_service.dart';
import 'package:axiom/src/features/categories/di/delete_category_use_case_provider.dart';
import 'package:axiom/src/features/categories/di/get_categories_use_case_provider.dart';
import 'package:axiom/src/features/categories/di/get_category_by_id_use_case_provider.dart';
import 'package:axiom/src/features/transactions/di/transactions_exist_by_category_id_use_case_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'delete_category_service_provider.g.dart';

/// Provides the service that deletes categories that are not in use.
@riverpod
DeleteCategoryService deleteCategoryService(Ref ref) {
  return DeleteCategoryService(
    getCategoryById: ref.watch(getCategoryByIdUseCaseProvider),
    getCategories: ref.watch(getCategoriesUseCaseProvider),
    transactionsExist: ref.watch(transactionsExistByCategoryIdUseCaseProvider),
    deleteCategory: ref.watch(deleteCategoryUseCaseProvider),
  );
}
