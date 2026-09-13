import 'package:axiom/src/features/categories/application/use_cases/restore_category_use_case.dart';
import 'package:axiom/src/features/categories/di/category_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'restore_category_use_case_provider.g.dart';

/// Provides the use case for restoring one category.
@riverpod
RestoreCategoryUseCase restoreCategoryUseCase(Ref ref) {
  return RestoreCategoryUseCase(ref.watch(categoryRepositoryProvider));
}
