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
import 'package:axiom/src/features/tags/domain/failures/tag_repository_failure.dart';
import 'package:axiom/src/features/tags/domain/repositories/tag_repository.dart';
import 'package:axiom/src/features/tags/domain/validation/tag_name_normalization.dart';
import 'package:sembast/sembast.dart';

/// Persists tags in [SembastStores.tags].
///
/// Tag identity is represented by the Sembast record key.
///
/// Names are indexed through the persisted canonical
/// [TagPersistenceModel.nameKeyField]. Current records can therefore be located
/// directly by canonical name.
///
/// Records created before the name key was introduced remain readable. Name
/// lookup performs a fallback scan over legacy records lacking that field.
///
/// A conflicting or inconsistent persisted name key is treated as corruption
/// and translated to [TagRepositoryFailure].
///
/// Tag deletion is physical. Cross-feature transaction usage validation occurs
/// before [delete], outside this repository.
final class SembastTagRepositoryImpl implements TagRepository {
  static final StoreRef<String, PersistenceRecord> _store = SembastStores.tags;

  final Database _database;

  /// Creates a repository backed by an already validated database.
  SembastTagRepositoryImpl({required Database database})
    : _database = database; // ignore: prefer_initializing_formals

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

          final archived = _withArchivedAt(
            tag,
            archivedAt: archivedAt,
            modifiedAt: archivedAt,
          );

          await record.put(
            transaction,
            TagPersistenceModel.fromEntity(archived).toRecord(),
          );

          return Success(archived);
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

          final conflict = await _findByNameKey(
            transaction,
            tagNameKey(tag.name),
          );

          if (conflict != null) {
            return TagNameAlreadyExistsFailure(
              message: 'Tag name already exists: ${tag.name}',
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

          final deleted = _withDeletedAt(tag, createClock().nowUtc);

          await record.delete(transaction);

          return Success(deleted);
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

        return Success<Tag?>(
          _tagFromRecord(recordKey: id.value, record: record),
        );
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

    final restored = _withDeletedAt(tag, null);

    return guardPersistenceOperation<void, TagFailure>(
      operation: () {
        return _database.transaction<Result<void, TagFailure>>((
          transaction,
        ) async {
          final record = _store.record(restored.id.value);

          if (await record.exists(transaction)) {
            return TagAlreadyExistsFailure(
              message: 'Tag ID already exists: ${restored.id.value}',
            );
          }

          final conflict = await _findByNameKey(
            transaction,
            tagNameKey(restored.name),
          );

          if (conflict != null) {
            return TagNameAlreadyExistsFailure(
              message: 'Tag name already exists: ${restored.name}',
            );
          }

          await record.put(
            transaction,
            TagPersistenceModel.fromEntity(restored).toRecord(),
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

          final unarchived = _withArchivedAt(
            tag,
            archivedAt: null,
            modifiedAt: modifiedAt,
          );

          await record.put(
            transaction,
            TagPersistenceModel.fromEntity(unarchived).toRecord(),
          );

          return Success(unarchived);
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

          final conflict = await _findByNameKey(
            transaction,
            tagNameKey(tag.name),
            excludingId: tag.id,
          );

          if (conflict != null) {
            return TagNameAlreadyExistsFailure(
              message: 'Tag name already exists: ${tag.name}',
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

  /// Locates the owner of [nameKey].
  ///
  /// Current records use a direct persisted-field filter.
  ///
  /// Legacy records lacking the field are scanned separately. This preserves
  /// compatibility with records created before the index field existed while
  /// still detecting cross-version uniqueness conflicts.
  static Future<Tag?> _findByNameKey(
    DatabaseClient databaseClient,
    String nameKey, {
    TagId? excludingId,
  }) async {
    Tag? found;

    void consider(Tag candidate) {
      if (excludingId != null && candidate.id == excludingId) {
        return;
      }

      if (found != null && found!.id != candidate.id) {
        throw const PersistenceRecordException(
          field: TagPersistenceModel.nameKeyField,
          reason: 'More than one persisted tag owns the same name index key.',
        );
      }

      found = candidate;
    }

    final indexedSnapshots = await _store.find(
      databaseClient,
      finder: Finder(
        filter: Filter.equals(TagPersistenceModel.nameKeyField, nameKey),
      ),
    );

    for (final snapshot in indexedSnapshots) {
      consider(_tagFromSnapshot(snapshot));
    }

    // Compatibility path for records persisted before `nameKey` existed.
    final allSnapshots = await _store.find(databaseClient);

    for (final snapshot in allSnapshots) {
      if (snapshot.value.containsKey(TagPersistenceModel.nameKeyField)) {
        continue;
      }

      final tag = _tagFromSnapshot(snapshot);

      if (tagNameKey(tag.name) == nameKey) {
        consider(tag);
      }
    }

    return found;
  }

  static Future<List<Tag>> _loadAllTags(DatabaseClient databaseClient) async {
    final snapshots = await _store.find(databaseClient);

    return snapshots.map(_tagFromSnapshot).toList(growable: false);
  }

  static TagNotFoundFailure _notFound(TagId id) {
    return TagNotFoundFailure(message: 'Tag ID was not found: ${id.value}');
  }

  static TagRepositoryFailure _persistenceFailure(String message) {
    return TagRepositoryFailure(message: message);
  }

  static String _searchKey(String query) {
    return query.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
  }

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

  static Tag _tagFromSnapshot(
    RecordSnapshot<String, PersistenceRecord> snapshot,
  ) {
    return _tagFromRecord(recordKey: snapshot.key, record: snapshot.value);
  }

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
