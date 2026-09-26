import 'package:axiom/src/core/identity/ids/tag_id.dart';
import 'package:axiom/src/features/tags/di/archive_tag_use_case_provider.dart';
import 'package:axiom/src/features/tags/di/create_tag_use_case_provider.dart';
import 'package:axiom/src/features/tags/di/unarchive_tag_use_case_provider.dart';
import 'package:axiom/src/features/tags/di/update_tag_use_case_provider.dart';
import 'package:flutter_riverpod/experimental/mutation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../application/di/services/delete_tag_service_provider.dart';
import '../../../../core/failures/base_failure.dart';
import '../../../../core/result/result.dart';
import '../../domain/entities/tag.dart';
import '../providers/tags_state.dart';

final createTagMutation = Mutation<Result<Object?, BaseFailure>>(
  label: 'create-tag',
);

final updateTagMutation = Mutation<Result<Object?, BaseFailure>>(
  label: 'update-tag',
);

final archiveTagMutation = Mutation<Result<Object?, BaseFailure>>(
  label: 'archive-tag',
);

final unarchiveTagMutation = Mutation<Result<Object?, BaseFailure>>(
  label: 'unarchive-tag',
);

final deleteTagMutation = Mutation<Result<Object?, BaseFailure>>(
  label: 'delete-tag',
);

Future<Result<Object?, BaseFailure>> executeCreateTag(
  WidgetRef ref,
  String name,
) {
  return createTagMutation.run(ref, (transaction) async {
    final useCase = transaction.get(createTagUseCaseProvider);
    final result = await useCase(name);

    final widened = result.when<Result<Object?, BaseFailure>>(
      success: (value) => Success<Object?>(value),
      failure: (failure) => failure,
    );

    if (widened.isSuccess) {
      _invalidateTags(ref);
    }

    return widened;
  });
}

Future<Result<Object?, BaseFailure>> executeUpdateTag(
  WidgetRef ref, {
  required Tag tag,
  required String name,
}) {
  final mutation = updateTagMutation(tag.id);

  return mutation.run(ref, (transaction) async {
    final useCase = transaction.get(updateTagUseCaseProvider);

    final updated = tag.copyWith(name: name);

    final result = await useCase(updated);

    final widened = result.when<Result<Object?, BaseFailure>>(
      success: (_) => Success<Object?>(null),
      failure: (failure) => failure,
    );

    if (widened.isSuccess) {
      _invalidateTags(ref);
    }

    return widened;
  });
}

Future<Result<Object?, BaseFailure>> executeArchiveTag(
  WidgetRef ref,
  TagId tagId,
) {
  final mutation = archiveTagMutation(tagId);

  return mutation.run(ref, (transaction) async {
    final useCase = transaction.get(archiveTagUseCaseProvider);
    final result = await useCase(tagId);

    final widened = result.when<Result<Object?, BaseFailure>>(
      success: (value) => Success<Object?>(value),
      failure: (failure) => failure,
    );

    if (widened.isSuccess) {
      _invalidateTags(ref);
    }

    return widened;
  });
}

Future<Result<Object?, BaseFailure>> executeUnarchiveTag(
  WidgetRef ref,
  TagId tagId,
) {
  final mutation = unarchiveTagMutation(tagId);

  return mutation.run(ref, (transaction) async {
    final useCase = transaction.get(unarchiveTagUseCaseProvider);
    final result = await useCase(tagId);

    final widened = result.when<Result<Object?, BaseFailure>>(
      success: (value) => Success<Object?>(value),
      failure: (failure) => failure,
    );

    if (widened.isSuccess) {
      _invalidateTags(ref);
    }

    return widened;
  });
}

Future<Result<Object?, BaseFailure>> executeDeleteTag(
  WidgetRef ref,
  TagId tagId,
) {
  final mutation = deleteTagMutation(tagId);

  return mutation.run(ref, (transaction) async {
    // Important: use the cross-feature service, not DeleteTagUseCase.
    //
    // The service removes transaction references before physically deleting
    // the tag, preserving referential integrity.
    final service = transaction.get(deleteTagServiceProvider);
    final result = await service(tagId);

    final widened = result.when<Result<Object?, BaseFailure>>(
      success: (value) => Success<Object?>(value),
      failure: (failure) => failure,
    );

    if (widened.isSuccess) {
      _invalidateTags(ref);
    }

    return widened;
  });
}

void _invalidateTags(WidgetRef ref) {
  ref
    ..invalidate(tagsProvider)
    ..invalidate(activeTagsProvider)
    ..invalidate(visibleTagsProvider);
}
