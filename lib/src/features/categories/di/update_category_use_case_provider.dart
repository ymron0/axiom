import 'package:axiom/src/features/categories/application/use_cases/update_category_use_case.dart';
import 'package:axiom/src/features/categories/di/category_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'update_category_use_case_provider.g.dart';

/// Provides the use case for updating one category.
@riverpod
UpdateCategoryUseCase updateCategoryUseCase(Ref ref) {
  return UpdateCategoryUseCase(ref.watch(categoryRepositoryProvider));
}
