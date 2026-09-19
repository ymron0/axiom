import 'package:axiom/src/features/tags/application/use_cases/get_active_tags_use_case.dart';
import 'package:axiom/src/features/tags/di/tag_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'get_active_tags_use_case_provider.g.dart';

/// Provides the use case for retrieving active tags.
@riverpod
GetActiveTagsUseCase getActiveTagsUseCase(Ref ref) {
  return GetActiveTagsUseCase(ref.watch(tagRepositoryProvider));
}
