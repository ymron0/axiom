import 'package:axiom/src/core/di/clock_provider.dart';
import 'package:axiom/src/features/categories/application/use_cases/unarchive_category_use_case.dart';
import 'package:axiom/src/features/categories/di/category_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'unarchive_category_use_case_provider.g.dart';

/// Provides the use case for unarchiving a category and its sub-categories.
@riverpod
UnarchiveCategoryUseCase unarchiveCategoryUseCase(Ref ref) {
  return UnarchiveCategoryUseCase(
    repository: ref.watch(categoryRepositoryProvider),
    clock: ref.watch(clockProvider),
  );
}
