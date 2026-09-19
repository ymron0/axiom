import 'package:axiom/src/features/tags/application/use_cases/get_tags_use_case.dart';
import 'package:axiom/src/features/tags/di/tag_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'get_tags_use_case_provider.g.dart';

/// Provides the use case for retrieving all tags.
@riverpod
GetTagsUseCase getTagsUseCase(Ref ref) {
  return GetTagsUseCase(ref.watch(tagRepositoryProvider));
}
