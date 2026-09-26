import 'package:axiom/src/features/categories/application/queries/category_watch_queries.dart';
import 'package:axiom/src/features/categories/di/category_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'category_watch_queries_provider.g.dart';

/// Provides reactive category queries backed by the configured repository.
@riverpod
CategoryWatchQueries categoryWatchQueries(Ref ref) {
  return CategoryWatchQueries(ref.watch(categoryRepositoryProvider));
}
