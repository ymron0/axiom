import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/identity/ids/tag_id.dart';
import 'package:axiom/src/core/ports/clock/clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/tags/application/use_cases/archive_tag_use_case.dart';
import 'package:axiom/src/features/tags/application/use_cases/delete_tag_use_case.dart';
import 'package:axiom/src/features/tags/application/use_cases/get_tag_by_id_use_case.dart';
import 'package:axiom/src/features/tags/domain/entities/tag.dart';
import 'package:axiom/src/features/tags/domain/failures/invalid_tag_merge_failure.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_failure.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_in_use_failure.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_not_assignable_failure.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_not_found_failure.dart';
import 'package:axiom/src/features/transactions/application/use_cases/get_transactions_by_tag_id_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/transactions_exist_by_tag_id_use_case.dart';
import 'package:axiom/src/features/transactions/application/use_cases/update_transaction_use_case.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_failure.dart';

/// Merges one tag into another without losing transaction metadata.
///
/// The source tag is archived before transaction references are rewritten.
/// This prevents normal application workflows from creating new source
/// references during the merge.
///
/// The operation is deliberately recoverable rather than falsely claiming
/// cross-repository atomicity:
///
/// - already migrated transactions no longer reference the source;
/// - a failed merge leaves the source archived rather than deleted;
/// - retrying continues with only the remaining source references; and
/// - the source is physically deleted only after a final reference check.
final class MergeTagsService {
  final Clock _clock;
  final GetTagByIdUseCase _getTagById;
  final ArchiveTagUseCase _archiveTag;
  final GetTransactionsByTagIdUseCase _getTransactionsByTagId;
  final UpdateTransactionUseCase _updateTransaction;
  final TransactionsExistByTagIdUseCase _transactionsExistByTagId;
  final DeleteTagUseCase _deleteTag;

  /// Creates a tag merge workflow.
  const MergeTagsService({
    required Clock clock,
    required GetTagByIdUseCase getTagById,
    required ArchiveTagUseCase archiveTag,
    required GetTransactionsByTagIdUseCase getTransactionsByTagId,
    required UpdateTransactionUseCase updateTransaction,
    required TransactionsExistByTagIdUseCase transactionsExistByTagId,
    required DeleteTagUseCase deleteTag,
  }) : _clock = clock, // ignore: prefer_initializing_formals
       _getTagById = getTagById, // ignore: prefer_initializing_formals
       _archiveTag = archiveTag, // ignore: prefer_initializing_formals
       _getTransactionsByTagId = // ignore: prefer_initializing_formals
           getTransactionsByTagId,
       _updateTransaction = // ignore: prefer_initializing_formals
           updateTransaction,
       _transactionsExistByTagId = // ignore: prefer_initializing_formals
           transactionsExistByTagId,
       _deleteTag = deleteTag; // ignore: prefer_initializing_formals

  /// Replaces every [sourceTagId] transaction reference with [targetTagId].
  ///
  /// Returns the surviving target tag on success.
  Future<Result<Tag, BaseFailure>> call({
    required TagId sourceTagId,
    required TagId targetTagId,
  }) async {
    if (sourceTagId == targetTagId) {
      return InvalidTagMergeFailure(
        message: 'A tag cannot be merged into itself: ${sourceTagId.value}',
      );
    }

    final sourceResult = await _getTagById(sourceTagId);

    if (sourceResult case final Failure<TagFailure> failure) {
      return failure;
    }

    var source = sourceResult.valueOrNull;

    if (source == null) {
      return TagNotFoundFailure(
        message: 'Source tag ID was not found: ${sourceTagId.value}',
      );
    }

    final targetResult = await _getTagById(targetTagId);

    if (targetResult case final Failure<TagFailure> failure) {
      return failure;
    }

    final target = targetResult.valueOrNull;

    if (target == null) {
      return TagNotFoundFailure(
        message: 'Target tag ID was not found: ${targetTagId.value}',
      );
    }

    if (target.isArchived) {
      return TagNotAssignableFailure(
        message:
            'Merge target must be active because transactions will receive it: '
            '${target.id.value}',
      );
    }

    if (!source.isArchived) {
      final archiveResult = await _archiveTag(source.id);

      if (archiveResult case final Failure<TagFailure> failure) {
        return failure;
      }

      source = archiveResult.valueOrNull!;
    }

    final transactionsResult = await _getTransactionsByTagId(source.id);

    if (transactionsResult case final Failure<TransactionFailure> failure) {
      return failure;
    }

    final modifiedAt = _clock.nowUtc;

    for (final transaction in transactionsResult.valueOrNull!) {
      final updated = transaction.copyWith(
        tagIds: _mergeTagIds(
          transaction.tagIds,
          sourceId: source.id,
          targetId: target.id,
        ),
        modifiedAt: modifiedAt,
      );

      final updateResult = await _updateTransaction(updated);

      if (updateResult case final Failure<TransactionFailure> failure) {
        return failure;
      }
    }

    final remainingResult = await _transactionsExistByTagId(source.id);

    if (remainingResult case final Failure<TransactionFailure> failure) {
      return failure;
    }

    if (remainingResult.valueOrNull!) {
      return TagInUseFailure(
        message:
            'Source tag still has transaction references after merge: '
            '${source.id.value}',
      );
    }

    final deleteResult = await _deleteTag(source.id);

    if (deleteResult case final Failure<TagFailure> failure) {
      return failure;
    }

    return Success(target);
  }

  /// Replaces [sourceId] with [targetId] while preserving tag order.
  ///
  /// When [targetId] is already attached, [sourceId] is simply removed so the
  /// resulting transaction cannot contain duplicate tag identities.
  static List<TagId> _mergeTagIds(
    List<TagId> tagIds, {
    required TagId sourceId,
    required TagId targetId,
  }) {
    final targetAlreadyPresent = tagIds.contains(targetId);
    final merged = <TagId>[];

    for (final id in tagIds) {
      if (id != sourceId) {
        merged.add(id);
        continue;
      }

      if (!targetAlreadyPresent) {
        merged.add(targetId);
      }
    }

    return List<TagId>.unmodifiable(merged);
  }
}
