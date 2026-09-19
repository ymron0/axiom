import 'package:axiom/src/features/tags/application/use_cases/get_archived_tags_use_case.dart';
import 'package:axiom/src/features/tags/di/tag_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'get_archived_tags_use_case_provider.g.dart';

/// Provides the use case for retrieving archived tags.
@riverpod
GetArchivedTagsUseCase getArchivedTagsUseCase(Ref ref) {
  return GetArchivedTagsUseCase(ref.watch(tagRepositoryProvider));
}
