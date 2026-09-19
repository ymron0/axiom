import 'package:axiom/src/features/tags/application/use_cases/get_tag_by_name_use_case.dart';
import 'package:axiom/src/features/tags/di/tag_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'get_tag_by_name_use_case_provider.g.dart';

/// Provides the use case for retrieving one tag by normalized name.
@riverpod
GetTagByNameUseCase getTagByNameUseCase(Ref ref) {
  return GetTagByNameUseCase(ref.watch(tagRepositoryProvider));
}
