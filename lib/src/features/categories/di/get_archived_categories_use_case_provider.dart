import 'package:axiom/src/features/categories/application/use_cases/get_archived_categories_use_case.dart';
import 'package:axiom/src/features/categories/di/category_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'get_archived_categories_use_case_provider.g.dart';

/// Provides the use case for retrieving archived categories.
@riverpod
GetArchivedCategoriesUseCase getArchivedCategoriesUseCase(Ref ref) {
  return GetArchivedCategoriesUseCase(ref.watch(categoryRepositoryProvider));
}
