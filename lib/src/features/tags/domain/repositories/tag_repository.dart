// coverage:ignore-file

import 'package:axiom/src/core/identity/ids/tag_id.dart';
import 'package:axiom/src/core/repositories/batch_lookup.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/tags/domain/entities/tag.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_already_active_failure.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_already_archived_failure.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_already_deleted_failure.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_already_exists_failure.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_failure.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_name_already_exists_failure.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_not_archived_failure.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_not_found_failure.dart';

/// Domain-facing contract for storing and retrieving [Tag] entities.
///
/// Tags are reusable transaction metadata. They do not participate in category
/// or jar allocation and may be independently attached to any transaction.
///
/// ## Name uniqueness
///
/// Persisted tag names are unique according to their normalized comparison key.
///
/// Consequently:
///
/// ```text
/// "Business Trip"
/// "business trip"
/// " business   trip "
/// ```
///
/// conflict with one another.
///
/// Archived tags remain persisted and therefore continue reserving their name.
///
/// ## Referential integrity
///
/// This repository deliberately does not depend on Transactions.
///
/// Before deleting a tag, the coordinating application operation must verify
/// that no persisted transaction references its [TagId].
///
/// Before assigning tag IDs to a transaction, the coordinating operation must
/// resolve the referenced tags and ensure they are valid for assignment.
///
/// Existing transactions may continue referencing archived tags. Archiving is
/// therefore the mechanism for retiring a tag without breaking historical
/// references.
///
/// ## Persistence semantics
///
/// Tags with a non-null [Tag.deletedAt] are absent from persistence.
///
/// Archived tags remain persisted.
///
/// Deletion is physical. The repository returns the deleted snapshot but does
/// not retain it. A caller requiring restoration must retain that snapshot.
abstract interface class TagRepository {
  /// Archives the tag identified by [id].
  ///
  /// [archivedAt] becomes its modification timestamp.
  ///
  /// Fails with [TagNotFoundFailure] when no matching tag exists.
  ///
  /// Fails with [TagAlreadyArchivedFailure] when the tag is already archived.
  Future<Result<Tag, TagFailure>> archive(TagId id, DateTime archivedAt);

  /// Stores a new active [tag].
  ///
  /// Fails with [TagAlreadyExistsFailure] when the identity already exists.
  ///
  /// Fails with [TagNameAlreadyExistsFailure] when another persisted tag has
  /// the same normalized name.
  ///
  /// Fails with [TagAlreadyDeletedFailure] when [Tag.deletedAt] is non-null.
  Future<Result<void, TagFailure>> create(Tag tag);

  /// Physically removes the tag identified by [id].
  ///
  /// Fails with [TagNotFoundFailure] when the tag does not exist.
  ///
  /// Returns the removed snapshot with [Tag.deletedAt] set to the deletion
  /// timestamp.
  ///
  /// Referential-integrity checks against transactions must occur before this
  /// method is called.
  Future<Result<Tag, TagFailure>> delete(TagId id);

  /// Returns persisted tags that are not archived.
  Future<Result<List<Tag>, TagFailure>> getActive();

  /// Returns all persisted tags.
  Future<Result<List<Tag>, TagFailure>> getAll();

  /// Returns persisted tags that are archived.
  Future<Result<List<Tag>, TagFailure>> getArchived();

  /// Returns the persisted tag identified by [id].
  ///
  /// Returns `null` when no matching tag exists.
  Future<Result<Tag?, TagFailure>> getById(TagId id);

  /// Resolves several tag identities in one operation.
  ///
  /// Duplicate requested IDs are reported once, in their first-seen order.
  /// Missing IDs are returned through [BatchLookup.missing].
  ///
  /// This operation is intended in particular for validating transaction tag
  /// references without issuing one lookup per tag.
  Future<Result<BatchLookup<Tag, TagId>, TagFailure>> getByIds(List<TagId> ids);

  /// Returns the persisted tag whose normalized name equals [name].
  ///
  /// Matching uses the same normalization and case-insensitive comparison used
  /// for repository uniqueness.
  ///
  /// Returns `null` when no tag has that normalized name.
  Future<Result<Tag?, TagFailure>> getByName(String name);

  /// Restores a caller-retained deleted [tag].
  ///
  /// On success, stores a non-deleted copy with [Tag.deletedAt] set to `null`.
  /// Any previous archival state is retained.
  ///
  /// Fails with [TagAlreadyActiveFailure] when [tag] is not deleted.
  ///
  /// Fails with [TagAlreadyExistsFailure] when its identity already exists.
  ///
  /// Fails with [TagNameAlreadyExistsFailure] when its normalized name belongs
  /// to another persisted tag.
  Future<Result<void, TagFailure>> restore(Tag tag);

  /// Returns tags whose normalized display name contains [query].
  ///
  /// Matching is case-insensitive.
  ///
  /// Returns an empty list when no tags match.
  Future<Result<List<Tag>, TagFailure>> search(String query);

  /// Removes archival state from the tag identified by [id].
  ///
  /// [modifiedAt] becomes its modification timestamp.
  ///
  /// Fails with [TagNotFoundFailure] when no matching tag exists.
  ///
  /// Fails with [TagNotArchivedFailure] when the tag is already active.
  Future<Result<Tag, TagFailure>> unarchive(TagId id, DateTime modifiedAt);

  /// Replaces the persisted snapshot of [tag].
  ///
  /// Fails with [TagNotFoundFailure] when its identity does not exist.
  ///
  /// Fails with [TagAlreadyDeletedFailure] when [tag] is deleted.
  ///
  /// Fails with [TagNameAlreadyExistsFailure] when another tag owns the same
  /// normalized name.
  Future<Result<void, TagFailure>> update(Tag tag);
}
