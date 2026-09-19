import 'package:axiom/src/features/tags/application/use_cases/get_tags_by_ids_use_case.dart';
import 'package:axiom/src/features/tags/di/tag_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'get_tags_by_ids_use_case_provider.g.dart';

/// Provides the use case for resolving several tag identities.
@riverpod
GetTagsByIdsUseCase getTagsByIdsUseCase(Ref ref) {
  return GetTagsByIdsUseCase(ref.watch(tagRepositoryProvider));
}
