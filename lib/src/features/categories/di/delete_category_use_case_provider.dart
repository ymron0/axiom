import 'package:axiom/src/features/categories/application/use_cases/delete_category_use_case.dart';
import 'package:axiom/src/features/categories/di/category_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'delete_category_use_case_provider.g.dart';

/// Provides the use case for deleting one category.
@riverpod
DeleteCategoryUseCase deleteCategoryUseCase(Ref ref) {
  return DeleteCategoryUseCase(ref.watch(categoryRepositoryProvider));
}
