import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/core/presentation/mutations/result_mutation_state.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/categories/di/category_watch_queries_provider.dart';
import 'package:axiom/src/features/categories/domain/entities/category.dart';
import 'package:axiom/src/features/categories/domain/failures/category_not_found_failure.dart';
import 'package:axiom/src/features/categories/presentation/state/categories_view_controller.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'categories_state.g.dart';

/// Watches categories from persistence.
@riverpod
Stream<Result<List<Category>, BaseFailure>> categories(Ref ref) {
  return ref.watch(categoryWatchQueriesProvider).all().map((result) {
    return widenResult(result);
  });
}

/// Applies presentation-only filtering to the watched category collection.
@riverpod
AsyncValue<Result<List<Category>, BaseFailure>> visibleCategories(Ref ref) {
  final source = ref.watch(categoriesProvider);
  final state = ref.watch(categoriesViewControllerProvider);

  return source.when(
    loading: () => const AsyncLoading(),
    error: (error, stackTrace) => AsyncError(error, stackTrace),
    data: (result) {
      final visible = result.when<Result<List<Category>, BaseFailure>>(
        success: (categories) {
          final query = state.searchQuery.trim().toLowerCase();

          final filtered =
              categories
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

                  return left.name.toLowerCase().compareTo(
                    right.name.toLowerCase(),
                  );
                });

          return Success(List.unmodifiable(filtered));
        },
        failure: (failure) => failure,
      );

      return AsyncData(visible);
    },
  );
}

/// Watches one category for details and editing.
@riverpod
Stream<Result<Category, BaseFailure>> categoryDetails(
  Ref ref,
  CategoryId categoryId,
) {
  return ref.watch(categoryWatchQueriesProvider).byId(categoryId).map((result) {
    return result.when<Result<Category, BaseFailure>>(
      success: (category) {
        if (category == null) {
          return CategoryNotFoundFailure(
            message: 'Category ID was not found: ${categoryId.value}',
          );
        }

        return Success(category);
      },
      failure: (failure) => failure,
    );
  });
}
