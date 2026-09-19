import 'package:axiom/src/features/tags/application/use_cases/update_tag_use_case.dart';
import 'package:axiom/src/features/tags/di/tag_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'update_tag_use_case_provider.g.dart';

/// Provides the use case for updating tags.
@riverpod
UpdateTagUseCase updateTagUseCase(Ref ref) {
  return UpdateTagUseCase(ref.watch(tagRepositoryProvider));
}
