import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/features/categories/di/get_categories_use_case_provider.dart';
import 'package:axiom/src/features/categories/di/get_category_by_id_use_case_provider.dart';
import 'package:axiom/src/features/categories/domain/failures/category_failure.dart';
import 'package:axiom/src/features/categories/domain/failures/category_not_found_failure.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/failures/base_failure.dart';
import '../../../../core/presentation/mutations/result_mutation_state.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/category.dart';
import '../state/categories_view_controller.dart';

part 'categories_state.g.dart';

/// Loads categories from the application boundary.
@riverpod
Future<Result<List<Category>, BaseFailure>> categories(Ref ref) async {
  final useCase = ref.watch(getCategoriesUseCaseProvider);
  final result = await useCase();

  return widenResult(result);
}

/// Applies presentation-only filtering to [categoriesProvider].
@riverpod
Future<Result<List<Category>, BaseFailure>> visibleCategories(Ref ref) async {
  final source = await ref.watch(categoriesProvider.future);

  if (source case final Failure<BaseFailure> failure) {
    return failure;
  }

  final state = ref.watch(categoriesViewControllerProvider);
  final query = state.searchQuery.trim().toLowerCase();

  final categories =
      source.valueOrNull!
          .where((category) {
            if (!state.includeDeleted && category.isDeleted) {
              return false;
            }

            if (state.kind != null && category.kind != state.kind) {
              return false;
            }

            if (query.isNotEmpty &&
                !category.name.toLowerCase().contains(query)) {
              return false;
            }

            return true;
          })
          .toList(growable: false)
        ..sort((left, right) {
          final sortOrder = left.sortOrder.compareTo(right.sortOrder);
          if (sortOrder != 0) {
            return sortOrder;
          }

          return left.name.toLowerCase().compareTo(right.name.toLowerCase());
        });

  return Success(categories);
}

/// Loads one category for a details/edit route.
@riverpod
Future<Result<Category, BaseFailure>> categoryDetails(
  Ref ref,
  CategoryId categoryId,
) async {
  final useCase = ref.watch(getCategoryByIdUseCaseProvider);
  final result = await useCase(categoryId);

  if (result case final Failure<CategoryFailure> failure) {
    return failure;
  }

  final category = result.valueOrNull;

  if (category == null) {
    return CategoryNotFoundFailure(
      message: 'Category ID was not found: ${categoryId.value}',
    );
  }

  return Success(category);
}
