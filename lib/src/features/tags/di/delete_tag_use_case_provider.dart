import 'package:axiom/src/features/tags/application/use_cases/delete_tag_use_case.dart';
import 'package:axiom/src/features/tags/di/tag_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'delete_tag_use_case_provider.g.dart';

/// Provides the feature-local use case for deleting tags.
@riverpod
DeleteTagUseCase deleteTagUseCase(Ref ref) {
  return DeleteTagUseCase(ref.watch(tagRepositoryProvider));
}
