import 'package:axiom/src/features/categories/data/repositories/in_memory_category_repository_impl.dart';
import 'package:axiom/src/features/categories/domain/repositories/category_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'category_repository_provider.g.dart';

/// Provides the repository used by the categories feature.
@riverpod
CategoryRepository categoryRepository(Ref ref) {
  return InMemoryCategoryRepositoryImpl();
}
