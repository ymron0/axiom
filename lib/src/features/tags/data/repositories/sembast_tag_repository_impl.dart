import 'package:axiom/src/core/identity/ids/tag_id.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_exception.dart';
import 'package:axiom/src/core/persistence/persistence_operation_guard.dart';
import 'package:axiom/src/core/persistence/sembast_stores.dart';
import 'package:axiom/src/core/ports/clock/clock_factory.dart';
import 'package:axiom/src/core/repositories/batch_lookup.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/tags/data/models/tag_persistence_model.dart';
import 'package:axiom/src/features/tags/domain/entities/tag.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_already_active_failure.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_already_archived_failure.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_already_deleted_failure.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_already_exists_failure.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_failure.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_name_already_exists_failure.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_not_archived_failure.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_not_found_failure.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_persistence_failure.dart';
import 'package:axiom/src/features/tags/domain/repositories/tag_repository.dart';
import 'package:axiom/src/features/tags/domain/validation/tag_name_normalization.dart';
import 'package:sembast/sembast.dart';

/// Persists tags in [SembastStores.tags].
///
/// ## Identity
///
/// [Tag.id] is used directly as the Sembast record key.
///
/// ## Name uniqueness
///
/// Tag names are unique according to [tagNameKey]. Archived tags remain
/// persisted and therefore continue reserving their normalized name.
///
/// Name checks and writes occur inside the same Sembast transaction so the
/// repository cannot observe one state and write against another state within
/// this store.
///
/// ## Deletion
///
/// Tag deletion is physical. Deleted snapshots are returned to the caller but
/// are not retained in persistence.
///
/// Cross-feature transaction reference checks deliberately do not belong here.
/// The coordinating application operation must establish that a tag is unused
/// before calling [delete].
///
/// ## Failure translation
///
/// Persistence infrastructure failures and malformed persisted records are
/// translated to [TagPersistenceFailure].
final class SembastTagRepositoryImpl implements TagRepository {
  static final StoreRef<String, PersistenceRecord> _store = SembastStores.tags;

  final Database _database;

  /// Creates a tag repository backed by an already-open [database].
  SembastTagRepositoryImpl({required Database database})
    : _database = // ignore: prefer_initializing_formals
          database;

  @override
  Future<Result<Tag, TagFailure>> archive(TagId id, DateTime archivedAt) {
    return guardPersistenceOperation<Tag, TagFailure>(
      operation: () {
        return _database.transaction<Result<Tag, TagFailure>>((
          transaction,
        ) async {
          final record = _store.record(id.value);
          final persistedRecord = await record.get(transaction);

          if (persistedRecord == null) {
            return _notFound(id);
          }

          final tag = _tagFromRecord(
            recordKey: id.value,
            record: persistedRecord,
          );

          if (tag.isArchived) {
            return TagAlreadyArchivedFailure(
              message: 'Tag is already archived: ${id.value}',
            );
          }

          final archivedTag = _withArchivedAt(
            tag,
            archivedAt: archivedAt,
            modifiedAt: archivedAt,
          );

          await record.put(
            transaction,
            TagPersistenceModel.fromEntity(archivedTag).toRecord(),
          );

          return Success(archivedTag);
        });
      },
      persistenceFailure: _persistenceFailure,
      failureMessage: 'Failed to archive tag.',
    );
  }

  @override
  Future<Result<void, TagFailure>> create(Tag tag) async {
    if (tag.isDeleted) {
      return TagAlreadyDeletedFailure(
        message: 'Deleted tag cannot be created: ${tag.id.value}',
      );
    }

    if (tag.isArchived) {
      return TagAlreadyArchivedFailure(
        message: 'Archived tag cannot be created: ${tag.id.value}',
      );
    }

    return guardPersistenceOperation<void, TagFailure>(
      operation: () {
        return _database.transaction<Result<void, TagFailure>>((
          transaction,
        ) async {
          final record = _store.record(tag.id.value);

          if (await record.exists(transaction)) {
            return TagAlreadyExistsFailure(
              message: 'Tag ID already exists: ${tag.id.value}',
            );
          }

          final conflictingTag = await _findByNameKey(
            transaction,
            tagNameKey(tag.name),
          );

          if (conflictingTag != null) {
            return TagNameAlreadyExistsFailure(
              message:
                  'Tag name already exists: '
                  '${tag.name}',
            );
          }

          await record.put(
            transaction,
            TagPersistenceModel.fromEntity(tag).toRecord(),
          );

          return const Success(null);
        });
      },
      persistenceFailure: _persistenceFailure,
      failureMessage: 'Failed to create tag.',
    );
  }

  @override
  Future<Result<Tag, TagFailure>> delete(TagId id) {
    return guardPersistenceOperation<Tag, TagFailure>(
      operation: () {
        return _database.transaction<Result<Tag, TagFailure>>((
          transaction,
        ) async {
          final record = _store.record(id.value);
          final persistedRecord = await record.get(transaction);

          if (persistedRecord == null) {
            return _notFound(id);
          }

          final tag = _tagFromRecord(
            recordKey: id.value,
            record: persistedRecord,
          );

          final deletedTag = _withDeletedAt(tag, createClock().nowUtc);

          await record.delete(transaction);

          return Success(deletedTag);
        });
      },
      persistenceFailure: _persistenceFailure,
      failureMessage: 'Failed to delete tag.',
    );
  }

  @override
  Future<Result<List<Tag>, TagFailure>> getActive() {
    return _readMatching(
      matches: (tag) => !tag.isArchived,
      failureMessage: 'Failed to read active tags.',
    );
  }

  @override
  Future<Result<List<Tag>, TagFailure>> getAll() {
    return _readMatching(
      matches: (_) => true,
      failureMessage: 'Failed to read tags.',
    );
  }

  @override
  Future<Result<List<Tag>, TagFailure>> getArchived() {
    return _readMatching(
      matches: (tag) => tag.isArchived,
      failureMessage: 'Failed to read archived tags.',
    );
  }

  @override
  Future<Result<Tag?, TagFailure>> getById(TagId id) {
    return guardPersistenceOperation<Tag?, TagFailure>(
      operation: () async {
        final record = await _store.record(id.value).get(_database);

        if (record == null) {
          return const Success(null);
        }

        return Success(_tagFromRecord(recordKey: id.value, record: record));
      },
      persistenceFailure: _persistenceFailure,
      failureMessage: 'Failed to read tag.',
    );
  }

  @override
  Future<Result<BatchLookup<Tag, TagId>, TagFailure>> getByIds(
    List<TagId> ids,
  ) {
    return guardPersistenceOperation<BatchLookup<Tag, TagId>, TagFailure>(
      operation: () async {
        final found = <Tag>[];
        final missing = <TagId>[];
        final seen = <TagId>{};

        for (final id in ids) {
          if (!seen.add(id)) {
            continue;
          }

          final record = await _store.record(id.value).get(_database);

          if (record == null) {
            missing.add(id);
            continue;
          }

          found.add(_tagFromRecord(recordKey: id.value, record: record));
        }

        return Success(BatchLookup<Tag, TagId>(found: found, missing: missing));
      },
      persistenceFailure: _persistenceFailure,
      failureMessage: 'Failed to read tags by ID.',
    );
  }

  @override
  Future<Result<Tag?, TagFailure>> getByName(String name) {
    final nameKey = tagNameKey(name);

    return guardPersistenceOperation<Tag?, TagFailure>(
      operation: () async {
        final tag = await _findByNameKey(_database, nameKey);

        return Success<Tag?>(tag);
      },
      persistenceFailure: _persistenceFailure,
      failureMessage: 'Failed to read tag by name.',
    );
  }

  @override
  Future<Result<void, TagFailure>> restore(Tag tag) async {
    if (!tag.isDeleted) {
      return TagAlreadyActiveFailure(
        message: 'Tag is already active: ${tag.id.value}',
      );
    }

    final restoredTag = _withDeletedAt(tag, null);

    return guardPersistenceOperation<void, TagFailure>(
      operation: () {
        return _database.transaction<Result<void, TagFailure>>((
          transaction,
        ) async {
          final record = _store.record(tag.id.value);

          if (await record.exists(transaction)) {
            return TagAlreadyExistsFailure(
              message: 'Tag ID already exists: ${tag.id.value}',
            );
          }

          final conflictingTag = await _findByNameKey(
            transaction,
            tagNameKey(restoredTag.name),
          );

          if (conflictingTag != null) {
            return TagNameAlreadyExistsFailure(
              message:
                  'Tag name already exists: '
                  '${restoredTag.name}',
            );
          }

          await record.put(
            transaction,
            TagPersistenceModel.fromEntity(restoredTag).toRecord(),
          );

          return const Success(null);
        });
      },
      persistenceFailure: _persistenceFailure,
      failureMessage: 'Failed to restore tag.',
    );
  }

  @override
  Future<Result<List<Tag>, TagFailure>> search(String query) {
    final queryKey = _searchKey(query);

    return _readMatching(
      matches: (tag) => tagNameKey(tag.name).contains(queryKey),
      failureMessage: 'Failed to search tags.',
    );
  }

  @override
  Future<Result<Tag, TagFailure>> unarchive(TagId id, DateTime modifiedAt) {
    return guardPersistenceOperation<Tag, TagFailure>(
      operation: () {
        return _database.transaction<Result<Tag, TagFailure>>((
          transaction,
        ) async {
          final record = _store.record(id.value);
          final persistedRecord = await record.get(transaction);

          if (persistedRecord == null) {
            return _notFound(id);
          }

          final tag = _tagFromRecord(
            recordKey: id.value,
            record: persistedRecord,
          );

          if (!tag.isArchived) {
            return TagNotArchivedFailure(
              message: 'Tag is not archived: ${id.value}',
            );
          }

          final unarchivedTag = _withArchivedAt(
            tag,
            archivedAt: null,
            modifiedAt: modifiedAt,
          );

          await record.put(
            transaction,
            TagPersistenceModel.fromEntity(unarchivedTag).toRecord(),
          );

          return Success(unarchivedTag);
        });
      },
      persistenceFailure: _persistenceFailure,
      failureMessage: 'Failed to unarchive tag.',
    );
  }

  @override
  Future<Result<void, TagFailure>> update(Tag tag) async {
    if (tag.isDeleted) {
      return TagAlreadyDeletedFailure(
        message: 'Deleted tag cannot be updated: ${tag.id.value}',
      );
    }

    return guardPersistenceOperation<void, TagFailure>(
      operation: () {
        return _database.transaction<Result<void, TagFailure>>((
          transaction,
        ) async {
          final record = _store.record(tag.id.value);

          if (!await record.exists(transaction)) {
            return _notFound(tag.id);
          }

          final conflictingTag = await _findByNameKey(
            transaction,
            tagNameKey(tag.name),
            excludingId: tag.id,
          );

          if (conflictingTag != null) {
            return TagNameAlreadyExistsFailure(
              message:
                  'Tag name already exists: '
                  '${tag.name}',
            );
          }

          await record.put(
            transaction,
            TagPersistenceModel.fromEntity(tag).toRecord(),
          );

          return const Success(null);
        });
      },
      persistenceFailure: _persistenceFailure,
      failureMessage: 'Failed to update tag.',
    );
  }

  /// Reads all persisted tags satisfying [matches].
  Future<Result<List<Tag>, TagFailure>> _readMatching({
    required bool Function(Tag tag) matches,
    required String failureMessage,
  }) {
    return guardPersistenceOperation<List<Tag>, TagFailure>(
      operation: () async {
        final tags = await _loadAllTags(_database);

        return Success(List<Tag>.unmodifiable(tags.where(matches)));
      },
      persistenceFailure: _persistenceFailure,
      failureMessage: failureMessage,
    );
  }

  /// Finds the tag owning [nameKey].
  ///
  /// [excludingId] is ignored while checking uniqueness during an update.
  static Future<Tag?> _findByNameKey(
    DatabaseClient databaseClient,
    String nameKey, {
    TagId? excludingId,
  }) async {
    final tags = await _loadAllTags(databaseClient);

    for (final tag in tags) {
      if (excludingId != null && tag.id == excludingId) {
        continue;
      }

      if (tagNameKey(tag.name) == nameKey) {
        return tag;
      }
    }

    return null;
  }

  /// Loads all persisted tag entities.
  static Future<List<Tag>> _loadAllTags(DatabaseClient databaseClient) async {
    final snapshots = await _store.find(databaseClient);

    return snapshots.map(_tagFromSnapshot).toList(growable: false);
  }

  /// Creates a typed missing-tag failure.
  static TagNotFoundFailure _notFound(TagId id) {
    return TagNotFoundFailure(message: 'Tag ID was not found: ${id.value}');
  }

  /// Creates the typed infrastructure failure exposed through [TagRepository].
  static TagPersistenceFailure _persistenceFailure(String message) {
    return TagPersistenceFailure(message: message);
  }

  /// Normalizes free-form search text.
  ///
  /// Unlike [tagNameKey], an empty search string is valid and therefore
  /// matches every tag.
  static String _searchKey(String query) {
    return query.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  }

  /// Converts persisted data into a valid active or archived tag.
  ///
  /// Deleted tags must never remain in the store because deletion is physical.
  static Tag _tagFromRecord({
    required String recordKey,
    required PersistenceRecord record,
  }) {
    final tag = TagPersistenceModel.fromRecord(
      recordKey: recordKey,
      record: record,
    ).toEntity();

    if (tag.isDeleted) {
      throw const PersistenceRecordException(
        field: TagPersistenceModel.deletedAtField,
        reason: 'Deleted tags must not be persisted.',
      );
    }

    return tag;
  }

  /// Converts one Sembast snapshot into a tag.
  static Tag _tagFromSnapshot(
    RecordSnapshot<String, PersistenceRecord> snapshot,
  ) {
    return _tagFromRecord(recordKey: snapshot.key, record: snapshot.value);
  }

  /// Creates a tag snapshot with a changed archival state.
  static Tag _withArchivedAt(
    Tag tag, {
    required DateTime? archivedAt,
    required DateTime modifiedAt,
  }) {
    return Tag(
      id: tag.id,
      name: tag.name,
      createdAt: tag.createdAt,
      modifiedAt: modifiedAt,
      archivedAt: archivedAt,
      deletedAt: tag.deletedAt,
      entityVersion: tag.entityVersion,
    );
  }

  /// Creates a tag snapshot with a changed deletion state.
  static Tag _withDeletedAt(Tag tag, DateTime? deletedAt) {
    return Tag(
      id: tag.id,
      name: tag.name,
      createdAt: tag.createdAt,
      modifiedAt: tag.modifiedAt,
      archivedAt: tag.archivedAt,
      deletedAt: deletedAt,
      entityVersion: tag.entityVersion,
    );
  }
}
