import 'package:axiom/src/core/di/clock_provider.dart';
import 'package:axiom/src/features/categories/application/use_cases/create_category_use_case.dart';
import 'package:axiom/src/features/categories/di/category_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'create_category_use_case_provider.g.dart';

/// Provides the use case for creating one category.
@riverpod
CreateCategoryUseCase createCategoryUseCase(Ref ref) {
  return CreateCategoryUseCase(
    repository: ref.watch(categoryRepositoryProvider),
    clock: ref.watch(clockProvider),
  );
}
