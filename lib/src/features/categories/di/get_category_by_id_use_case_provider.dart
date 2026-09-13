import 'package:axiom/src/features/categories/application/use_cases/get_category_by_id_use_case.dart';
import 'package:axiom/src/features/categories/di/category_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'get_category_by_id_use_case_provider.g.dart';

/// Provides the use case for retrieving one category by identifier.
@riverpod
GetCategoryByIdUseCase getCategoryByIdUseCase(Ref ref) {
  return GetCategoryByIdUseCase(ref.watch(categoryRepositoryProvider));
}
