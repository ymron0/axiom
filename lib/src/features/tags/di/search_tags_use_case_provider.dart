import 'package:axiom/src/features/tags/application/use_cases/search_tags_use_case.dart';
import 'package:axiom/src/features/tags/di/tag_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'search_tags_use_case_provider.g.dart';

/// Provides the use case for searching tags.
@riverpod
SearchTagsUseCase searchTagsUseCase(Ref ref) {
  return SearchTagsUseCase(ref.watch(tagRepositoryProvider));
}
