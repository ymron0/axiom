import 'package:axiom/src/core/di/clock_provider.dart';
import 'package:axiom/src/features/tags/application/use_cases/create_tag_use_case.dart';
import 'package:axiom/src/features/tags/di/tag_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'create_tag_use_case_provider.g.dart';

/// Provides the use case for creating tags.
@riverpod
CreateTagUseCase createTagUseCase(Ref ref) {
  return CreateTagUseCase(
    repository: ref.watch(tagRepositoryProvider),
    clock: ref.watch(clockProvider),
  );
}
