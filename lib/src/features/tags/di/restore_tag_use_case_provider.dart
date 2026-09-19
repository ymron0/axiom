import 'package:axiom/src/features/tags/application/use_cases/restore_tag_use_case.dart';
import 'package:axiom/src/features/tags/di/tag_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'restore_tag_use_case_provider.g.dart';

/// Provides the use case for restoring tags.
@riverpod
RestoreTagUseCase restoreTagUseCase(Ref ref) {
  return RestoreTagUseCase(ref.watch(tagRepositoryProvider));
}
