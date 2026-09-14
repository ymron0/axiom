import 'package:axiom/src/features/categories/application/use_cases/get_active_categories_use_case.dart';
import 'package:axiom/src/features/categories/di/category_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'get_active_categories_use_case_provider.g.dart';

/// Provides the use case for retrieving active categories.
@riverpod
GetActiveCategoriesUseCase getActiveCategoriesUseCase(Ref ref) {
  return GetActiveCategoriesUseCase(ref.watch(categoryRepositoryProvider));
}
