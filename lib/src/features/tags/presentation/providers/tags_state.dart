import 'package:axiom/src/features/tags/di/get_active_tags_use_case_provider.dart';
import 'package:axiom/src/features/tags/di/get_tags_use_case_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/failures/base_failure.dart';
import '../../../../core/presentation/mutations/result_mutation_state.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/tag.dart';
import '../state/tags_view_controller.dart';

part 'tags_state.g.dart';

/// All persisted tags exposed for management.
@riverpod
Future<Result<List<Tag>, BaseFailure>> tags(Ref ref) async {
  final useCase = ref.watch(getTagsUseCaseProvider);

  return widenResult(await useCase());
}

/// Assignable tags only.
///
/// Archived tags intentionally remain attached to historical transactions but
/// are not offered for new assignments.
@riverpod
Future<Result<List<Tag>, BaseFailure>> activeTags(Ref ref) async {
  final useCase = ref.watch(getActiveTagsUseCaseProvider);

  return widenResult(await useCase());
}

/// Locally filtered management view.
@riverpod
Future<Result<List<Tag>, BaseFailure>> visibleTags(Ref ref) async {
  final source = await ref.watch(tagsProvider.future);

  if (source case final Failure<BaseFailure> failure) {
    return failure;
  }

  final state = ref.watch(tagsViewControllerProvider);
  final query = state.searchQuery.trim().toLowerCase();

  final result =
      source.valueOrNull!
          .where((tag) {
            if (tag.isDeleted) {
              return false;
            }

            if (!state.includeArchived && tag.isArchived) {
              return false;
            }

            if (query.isNotEmpty && !tag.name.toLowerCase().contains(query)) {
              return false;
            }

            return true;
          })
          .toList(growable: false)
        ..sort(
          (left, right) =>
              left.name.toLowerCase().compareTo(right.name.toLowerCase()),
        );

  return Success(result);
}
