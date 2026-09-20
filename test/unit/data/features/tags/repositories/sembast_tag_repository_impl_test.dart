@Tags(['data', 'persistence'])
library;

import 'package:axiom/src/core/identity/ids/tag_id.dart';
import 'package:axiom/src/core/persistence/sembast_stores.dart';
import 'package:axiom/src/features/tags/data/repositories/sembast_tag_repository_impl.dart';
import 'package:axiom/src/features/tags/domain/entities/tag.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_already_active_failure.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_already_archived_failure.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_already_deleted_failure.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_already_exists_failure.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_name_already_exists_failure.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_not_archived_failure.dart';
import 'package:axiom/src/features/tags/domain/failures/tag_not_found_failure.dart';
import 'package:axiom/src/features/tags/data/failures/tag_persistence_failure.dart';
import 'package:axiom/src/features/tags/domain/repositories/tag_repository.dart';
import 'package:sembast/sembast.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/core/persistence/persistence_test_environment.dart';

void main() {
  late Database database;
  late TagRepository repository;

  final archivedAt = DateTime.utc(2026, 1, 2);
  final unarchivedAt = DateTime.utc(2026, 1, 3);
  final deletedAt = DateTime.utc(2026, 1, 4);

  setUp(() async {
    final sembastDatabase = await createTestSembastDatabase();
    database = await sembastDatabase.open();

    repository = SembastTagRepositoryImpl(database: database);
  });

  group('SembastTagRepositoryImpl', () {
    group('create', () {
      test('persists an active tag', () async {
        // Given
        final tag = _tag(id: 'create', name: 'Business');

        // When
        final result = await repository.create(tag);

        // Then
        expect(result.isSuccess, isTrue);

        final stored = (await repository.getById(tag.id)).valueOrNull!;

        expect(stored.id, tag.id);
        expect(stored.name, 'Business');
      });

      test('rejects duplicate identity', () async {
        // Given
        final original = _tag(id: 'duplicate', name: 'Original');
        final duplicate = _tag(id: 'duplicate', name: 'Replacement');

        await repository.create(original);

        // When
        final result = await repository.create(duplicate);

        // Then
        expect(result.failureOrNull, isA<TagAlreadyExistsFailure>());
      });

      test('rejects archived and deleted snapshots', () async {
        // Given
        final archived = _tag(
          id: 'archived',
          archivedAt: archivedAt,
          modifiedAt: archivedAt,
        );

        final deleted = _tag(id: 'deleted', deletedAt: deletedAt);

        // When
        final archivedResult = await repository.create(archived);
        final deletedResult = await repository.create(deleted);

        // Then
        expect(archivedResult.failureOrNull, isA<TagAlreadyArchivedFailure>());
        expect(deletedResult.failureOrNull, isA<TagAlreadyDeletedFailure>());
      });

      test('enforces normalized case-insensitive name uniqueness', () async {
        // Given
        final first = _tag(id: 'business-1', name: 'Business Trip');

        final second = _tag(id: 'business-2', name: 'BUSINESS   TRIP');

        await repository.create(first);

        // When
        final result = await repository.create(second);

        // Then
        expect(result.failureOrNull, isA<TagNameAlreadyExistsFailure>());

        expect((await repository.getById(second.id)).valueOrNull, isNull);
      });
    });

    group('queries', () {
      test('getAll returns an immutable collection', () async {
        // Given
        final first = _tag(id: 'all-first', name: 'First');
        final second = _tag(id: 'all-second', name: 'Second');

        await repository.create(first);
        await repository.create(second);

        // When
        final tags = (await repository.getAll()).valueOrNull!;

        // Then
        expect(
          tags.map((tag) => tag.id),
          unorderedEquals([first.id, second.id]),
        );

        expect(() => tags.clear(), throwsUnsupportedError);
      });

      test('getById returns successful null when missing', () async {
        // When
        final result = await repository.getById(TagId.fromString('missing'));

        // Then
        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull, isNull);
      });

      test('separates active and archived tags', () async {
        // Given
        final active = _tag(id: 'active');
        final archived = _tag(id: 'archive-me', name: 'Archived');

        await repository.create(active);
        await repository.create(archived);
        await repository.archive(archived.id, archivedAt);

        // When
        final activeTags = (await repository.getActive()).valueOrNull!;
        final archivedTags = (await repository.getArchived()).valueOrNull!;

        // Then
        expect(activeTags.map((tag) => tag.id), [active.id]);
        expect(archivedTags.map((tag) => tag.id), [archived.id]);

        expect(() => activeTags.clear(), throwsUnsupportedError);
        expect(() => archivedTags.clear(), throwsUnsupportedError);
      });

      test('getByIds preserves first requested occurrence', () async {
        // Given
        final first = _tag(id: 'batch-first', name: 'First');
        final second = _tag(id: 'batch-second', name: 'Second');

        await repository.create(first);
        await repository.create(second);

        final missing = TagId.fromString('batch-missing');

        // When
        final lookup = (await repository.getByIds([
          second.id,
          missing,
          first.id,
          second.id,
          missing,
        ])).valueOrNull!;

        // Then
        expect(lookup.found.map((tag) => tag.id), [second.id, first.id]);

        expect(lookup.missing, [missing]);

        expect(() => lookup.found.clear(), throwsUnsupportedError);
        expect(() => lookup.missing.clear(), throwsUnsupportedError);
      });

      test('getByName uses normalized case-insensitive equality', () async {
        // Given
        final tag = _tag(id: 'by-name', name: 'Business Trip');

        await repository.create(tag);

        // When
        final result = await repository.getByName('  BUSINESS   TRIP ');

        // Then
        expect(result.valueOrNull?.id, tag.id);
      });

      test(
        'search is normalized case-insensitive substring matching',
        () async {
          // Given
          final first = _tag(id: 'search-first', name: 'Business Travel');

          final second = _tag(id: 'search-second', name: 'Personal Travel');

          final unrelated = _tag(id: 'search-other', name: 'Tax');

          await repository.create(first);
          await repository.create(second);
          await repository.create(unrelated);

          // When
          final result = await repository.search(' TRAVEL ');

          // Then
          expect(
            result.valueOrNull!.map((tag) => tag.id),
            unorderedEquals([first.id, second.id]),
          );
        },
      );
    });

    group('update', () {
      test('replaces an existing tag snapshot', () async {
        // Given
        final original = _tag(id: 'update', name: 'Original');

        final replacement = _tag(
          id: original.id.value,
          name: 'Updated',
          modifiedAt: DateTime.utc(2026, 1, 5),
        );

        await repository.create(original);

        // When
        final result = await repository.update(replacement);

        // Then
        expect(result.isSuccess, isTrue);

        expect(
          (await repository.getById(original.id)).valueOrNull?.name,
          'Updated',
        );
      });

      test('allows retaining own normalized name', () async {
        // Given
        final original = _tag(id: 'same-name', name: 'Business Trip');

        await repository.create(original);

        final replacement = _tag(
          id: original.id.value,
          name: 'BUSINESS TRIP',
          modifiedAt: DateTime.utc(2026, 1, 5),
        );

        // When
        final result = await repository.update(replacement);

        // Then
        expect(result.isSuccess, isTrue);
      });

      test('rejects renaming to another tag name', () async {
        // Given
        final first = _tag(id: 'rename-first', name: 'Business');

        final second = _tag(id: 'rename-second', name: 'Personal');

        await repository.create(first);
        await repository.create(second);

        final replacement = _tag(
          id: second.id.value,
          name: ' BUSINESS ',
          modifiedAt: DateTime.utc(2026, 1, 5),
        );

        // When
        final result = await repository.update(replacement);

        // Then
        expect(result.failureOrNull, isA<TagNameAlreadyExistsFailure>());

        expect(
          (await repository.getById(second.id)).valueOrNull?.name,
          'Personal',
        );
      });

      test('returns typed failures for missing and deleted updates', () async {
        // Given
        final active = _tag(id: 'update-active');
        await repository.create(active);

        final deleted = _tag(id: active.id.value, deletedAt: deletedAt);

        // When
        final missingResult = await repository.update(
          _tag(id: 'update-missing'),
        );

        final deletedResult = await repository.update(deleted);

        // Then
        expect(missingResult.failureOrNull, isA<TagNotFoundFailure>());

        expect(deletedResult.failureOrNull, isA<TagAlreadyDeletedFailure>());
      });
    });

    group('archive and unarchive', () {
      test('persists both lifecycle transitions', () async {
        // Given
        final tag = _tag(id: 'lifecycle');
        await repository.create(tag);

        // When
        final archiveResult = await repository.archive(tag.id, archivedAt);

        final unarchiveResult = await repository.unarchive(
          tag.id,
          unarchivedAt,
        );

        // Then
        expect(archiveResult.valueOrNull?.archivedAt, archivedAt);
        expect(archiveResult.valueOrNull?.modifiedAt, archivedAt);

        expect(unarchiveResult.valueOrNull?.archivedAt, isNull);
        expect(unarchiveResult.valueOrNull?.modifiedAt, unarchivedAt);
      });

      test('returns typed failures for invalid transitions', () async {
        // Given
        final tag = _tag(id: 'invalid-transition');
        await repository.create(tag);

        // When
        final missing = await repository.archive(
          TagId.fromString('missing'),
          archivedAt,
        );

        await repository.archive(tag.id, archivedAt);

        final alreadyArchived = await repository.archive(tag.id, archivedAt);

        await repository.unarchive(tag.id, unarchivedAt);

        final notArchived = await repository.unarchive(tag.id, unarchivedAt);

        // Then
        expect(missing.failureOrNull, isA<TagNotFoundFailure>());

        expect(alreadyArchived.failureOrNull, isA<TagAlreadyArchivedFailure>());

        expect(notArchived.failureOrNull, isA<TagNotArchivedFailure>());
      });

      test('returns not-found when unarchiving a missing tag', () async {
        // Given
        final missing = TagId.fromString('unarchive-missing');

        // When
        final result = await repository.unarchive(missing, unarchivedAt);

        // Then
        expect(result.failureOrNull, isA<TagNotFoundFailure>());
      });
    });

    group('delete and restore', () {
      test('physically removes and restores a tag', () async {
        // Given
        final tag = _tag(id: 'delete-restore');
        await repository.create(tag);
        await repository.archive(tag.id, archivedAt);

        // When
        final deleteResult = await repository.delete(tag.id);

        // Then
        final deleted = deleteResult.valueOrNull!;

        expect(deleted.id, tag.id);
        expect(deleted.archivedAt, archivedAt);
        expect(deleted.deletedAt, isNotNull);

        expect((await repository.getById(tag.id)).valueOrNull, isNull);

        // When
        final restoreResult = await repository.restore(deleted);

        // Then
        expect(restoreResult.isSuccess, isTrue);

        final restored = (await repository.getById(tag.id)).valueOrNull!;

        expect(restored.deletedAt, isNull);
        expect(restored.archivedAt, archivedAt);
      });

      test('returns not-found when deletion target is missing', () async {
        // When
        final result = await repository.delete(
          TagId.fromString('delete-missing'),
        );

        // Then
        expect(result.failureOrNull, isA<TagNotFoundFailure>());
      });

      test('rejects restoring an active tag', () async {
        // Given
        final tag = _tag(id: 'restore-active');

        // When
        final result = await repository.restore(tag);

        // Then
        expect(result.failureOrNull, isA<TagAlreadyActiveFailure>());
      });

      test('rejects restore when identity already exists', () async {
        // Given
        final existing = _tag(id: 'restore-duplicate', name: 'Existing');

        await repository.create(existing);

        final deleted = _tag(
          id: existing.id.value,
          name: 'Deleted',
          deletedAt: deletedAt,
        );

        // When
        final result = await repository.restore(deleted);

        // Then
        expect(result.failureOrNull, isA<TagAlreadyExistsFailure>());
      });

      test('rejects restore when normalized name is already used', () async {
        // Given
        final existing = _tag(id: 'restore-name-existing', name: 'Business');

        await repository.create(existing);

        final deleted = _tag(
          id: 'restore-name-deleted',
          name: ' BUSINESS ',
          deletedAt: deletedAt,
        );

        // When
        final result = await repository.restore(deleted);

        // Then
        expect(result.failureOrNull, isA<TagNameAlreadyExistsFailure>());
      });
    });

    test('translates malformed persisted tag to typed failure', () async {
      // Given
      const id = 'corrupt-tag';

      await SembastStores.tags.record(id).put(database, <String, Object?>{});

      // When
      final result = await repository.getById(TagId.fromString(id));

      // Then
      expect(result.failureOrNull, isA<TagPersistenceFailure>());
    });

    test('rejects a persisted deleted tag as corrupt data', () async {
      // Given
      const id = 'persisted-deleted-tag';

      await SembastStores.tags.record(id).put(database, <String, Object?>{
        'name': 'Deleted',
        'createdAt': DateTime.utc(2026, 1, 1).toIso8601String(),
        'modifiedAt': DateTime.utc(2026, 1, 1).toIso8601String(),
        'archivedAt': null,
        'deletedAt': DateTime.utc(2026, 1, 2).toIso8601String(),
        'entityVersion': 1,
      });

      // When
      final result = await repository.getById(TagId.fromString(id));

      // Then
      expect(result.failureOrNull, isA<TagPersistenceFailure>());
    });
  });
}

Tag _tag({
  required String id,
  String name = 'Tag',
  DateTime? createdAt,
  DateTime? modifiedAt,
  DateTime? archivedAt,
  DateTime? deletedAt,
  int entityVersion = 1,
}) {
  final created = createdAt ?? DateTime.utc(2026, 1, 1);

  return Tag(
    id: TagId.fromString(id),
    name: name,
    createdAt: created,
    modifiedAt: modifiedAt ?? created,
    archivedAt: archivedAt,
    deletedAt: deletedAt,
    entityVersion: entityVersion,
  );
}
