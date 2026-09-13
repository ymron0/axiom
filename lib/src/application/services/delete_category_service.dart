import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/categories/application/use_cases/delete_category_use_case.dart';
import 'package:axiom/src/features/categories/application/use_cases/get_categories_use_case.dart';
import 'package:axiom/src/features/categories/application/use_cases/get_category_by_id_use_case.dart';
import 'package:axiom/src/features/categories/domain/entities/category.dart';
import 'package:axiom/src/features/categories/domain/failures/category_already_deleted_failure.dart';
import 'package:axiom/src/features/categories/domain/failures/category_failure.dart';
import 'package:axiom/src/features/categories/domain/failures/category_in_use_failure.dart';
import 'package:axiom/src/features/categories/domain/failures/category_not_found_failure.dart';
import 'package:axiom/src/features/transactions/application/use_cases/transactions_exist_by_category_id_use_case.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_failure.dart';

/// Deletes a category when its state, hierarchy, and usage permit deletion.
///
/// This service loads the category, rejects deleted categories and categories
/// with children, checks transaction usage, and delegates the physical removal
/// to [DeleteCategoryUseCase]. Cross-feature usage remains outside
/// `CategoryRepository`.
final class DeleteCategoryService {
  /// Creates a category deletion service.
  const DeleteCategoryService({
    required GetCategoryByIdUseCase getCategoryById,
    required GetCategoriesUseCase getCategories,
    required TransactionsExistByCategoryIdUseCase transactionsExist,
    required DeleteCategoryUseCase deleteCategory,
  }) : _getCategoryById = // ignore: prefer_initializing_formals
           getCategoryById,
       _getCategories = getCategories, // ignore: prefer_initializing_formals
       _transactionsExist = // ignore: prefer_initializing_formals
           transactionsExist,
       _deleteCategory = deleteCategory; // ignore: prefer_initializing_formals

  final GetCategoryByIdUseCase _getCategoryById;
  final GetCategoriesUseCase _getCategories;
  final TransactionsExistByCategoryIdUseCase _transactionsExist;
  final DeleteCategoryUseCase _deleteCategory;

  /// Deletes [categoryId] when no child or transaction references it.
  Future<Result<Category, BaseFailure>> call(CategoryId categoryId) async {
    final categoryResult = await _getCategoryById(categoryId);
    if (categoryResult case final Failure<CategoryFailure> failure) {
      return failure;
    }

    final category = categoryResult.valueOrNull;
    if (category == null) {
      return CategoryNotFoundFailure(
        message: 'Category ID was not found: ${categoryId.value}',
      );
    }
    if (category.isDeleted) {
      return CategoryAlreadyDeletedFailure(
        message: 'Category is already deleted: ${categoryId.value}',
      );
    }

    final categoriesResult = await _getCategories();
    if (categoriesResult case final Failure<CategoryFailure> failure) {
      return failure;
    }
    if (categoriesResult.valueOrNull!.any(
      (candidate) => candidate.parentCategoryId == categoryId,
    )) {
      return CategoryInUseFailure(
        message: 'Category is referenced by a child category: $categoryId',
      );
    }

    final usageResult = await _transactionsExist(categoryId);
    if (usageResult case final Failure<TransactionFailure> failure) {
      return failure;
    }
    if (usageResult.valueOrNull!) {
      return CategoryInUseFailure(
        message: 'Category is referenced by a transaction: $categoryId',
      );
    }

    return _deleteCategory(categoryId);
  }
}
