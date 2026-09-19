import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/identity/ids/tag_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/tags/application/use_cases/get_tags_by_ids_use_case.dart';
import 'package:axiom/src/features/tags/domain/entities/tag.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_failure.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_not_assignable_failure.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_not_found_failure.dart';

/// Validates transaction tag references requiring access to the Tags feature.
///
/// A newly assigned tag must exist and be active.
///
/// An archived tag may remain attached to an existing transaction and may be
/// restored as part of an historical transaction snapshot. This preserves
/// historical metadata after the tag has been retired.
///
/// Removed tag IDs are deliberately not resolved during an update. This allows
/// a damaged or legacy orphan reference to be removed safely.
final class ValidateTransactionTagsService {
  final GetTagsByIdsUseCase _getTagsByIds;

  /// Creates a transaction-tag reference validator.
  const ValidateTransactionTagsService({
    required GetTagsByIdsUseCase getTagsByIds,
  }) : _getTagsByIds = getTagsByIds; // ignore: prefer_initializing_formals

  /// Validates tags attached to a newly created transaction.
  Future<Result<void, BaseFailure>> validateForCreate(List<TagId> tagIds) {
    return _validate(
      tagIds: tagIds,
      previouslyAssigned: const <TagId>{},
      allowArchived: false,
    );
  }

  /// Validates the tag transition from [previousTagIds] to [nextTagIds].
  ///
  /// Archived tags already present in [previousTagIds] may remain attached.
  /// An archived tag not previously present is rejected as a new assignment.
  Future<Result<void, BaseFailure>> validateForUpdate({
    required List<TagId> previousTagIds,
    required List<TagId> nextTagIds,
  }) {
    return _validate(
      tagIds: nextTagIds,
      previouslyAssigned: previousTagIds.toSet(),
      allowArchived: false,
    );
  }

  /// Validates tags referenced by an historical transaction being restored.
  ///
  /// All tags must still exist, but archived tags remain valid.
  Future<Result<void, BaseFailure>> validateForRestore(List<TagId> tagIds) {
    return _validate(
      tagIds: tagIds,
      previouslyAssigned: const <TagId>{},
      allowArchived: true,
    );
  }

  Future<Result<void, BaseFailure>> _validate({
    required List<TagId> tagIds,
    required Set<TagId> previouslyAssigned,
    required bool allowArchived,
  }) async {
    if (tagIds.isEmpty) {
      return const Success(null);
    }

    final result = await _getTagsByIds(tagIds);

    if (result case final Failure<TagFailure> failure) {
      return failure;
    }

    final lookup = result.valueOrNull!;

    if (lookup.missing.isNotEmpty) {
      final missingIds = lookup.missing.map((id) => id.value).join(', ');

      return TagNotFoundFailure(
        message: 'Transaction references missing tag IDs: $missingIds',
      );
    }

    for (final Tag tag in lookup.found) {
      if (!tag.isArchived) {
        continue;
      }

      if (allowArchived || previouslyAssigned.contains(tag.id)) {
        continue;
      }

      return TagNotAssignableFailure(
        message:
            'Archived tag cannot be newly assigned to a transaction: '
            '${tag.id.value}',
      );
    }

    return const Success(null);
  }
}
