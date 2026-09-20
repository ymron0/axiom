@Tags(['data', 'persistence'])
library;

import 'package:axiom/src/core/identity/ids/jar_id.dart';
import 'package:axiom/src/core/persistence/sembast_stores.dart';
import 'package:axiom/src/features/jars/data/repositories/sembast_jar_repository_impl.dart';
import 'package:axiom/src/features/jars/domain/enums/jar_kind.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_already_archived_failure.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_already_deleted_failure.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_already_exists_failure.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_not_archived_failure.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_not_deleted_failure.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_not_found_failure.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_repository_failure.dart';
import 'package:axiom/src/features/jars/domain/repositories/jar_repository.dart';
import 'package:sembast/sembast.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/core/persistence/persistence_test_environment.dart';
import '../../../../../fixtures/features/jars/jar_fixtures.dart';

void main() {
  late Database database;
  late JarRepository repository;

  final archivedAt = DateTime.utc(2026, 1, 2);
  final modifiedAt = DateTime.utc(2026, 1, 3);
  final deletedAt = DateTime.utc(2026, 1, 4);

  setUp(() async {
    final sembastDatabase = await createTestSembastDatabase();
    database = await sembastDatabase.open();

    repository = SembastJarRepositoryImpl(database: database);
  });

  group('SembastJarRepositoryImpl', () {
    test('persists and reads a jar', () async {
      // Given
      final jar = jarFixture(id: 'create', name: 'Emergency fund');

      // When
      final result = await repository.create(jar);

      // Then
      expect(result.isSuccess, isTrue);

      final stored = (await repository.getById(jar.id)).valueOrNull;
      expect(stored?.id, jar.id);
      expect(stored?.name, jar.name);
      expect(stored?.kind, jar.kind);
    });

    test('returns typed create failures', () async {
      // Given
      final active = jarFixture(id: 'active-create');
      await repository.create(active);

      // When
      final duplicate = await repository.create(
        jarFixture(id: active.id.value, name: 'Duplicate'),
      );
      final archived = await repository.create(
        jarFixture(id: 'archived-create', archivedAt: archivedAt),
      );
      final deleted = await repository.create(
        jarFixture(id: 'deleted-create', deletedAt: deletedAt),
      );

      // Then
      expect(duplicate.failureOrNull, isA<JarAlreadyExistsFailure>());
      expect(archived.failureOrNull, isA<JarAlreadyArchivedFailure>());
      expect(deleted.failureOrNull, isA<JarAlreadyDeletedFailure>());
    });

    group('queries', () {
      test('returns all jars in an immutable list', () async {
        // Given
        final first = jarFixture(id: 'all-first');
        final second = jarFixture(id: 'all-second');

        await repository.create(second);
        await repository.create(first);

        // When
        final jars = (await repository.getAll()).valueOrNull!;

        // Then
        expect(
          jars.map((jar) => jar.id),
          unorderedEquals([first.id, second.id]),
        );
        expect(() => jars.clear(), throwsUnsupportedError);
      });

      test('returns successful null for missing ID', () async {
        // When
        final result = await repository.getById(JarId.fromString('missing'));

        // Then
        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull, isNull);
      });

      test('filters by kind and includes archived jars', () async {
        // Given
        final first = jarFixture(id: 'kind-first', kind: JarKind.reserve);
        final archived = jarFixture(id: 'kind-archived', kind: JarKind.reserve);
        final unrelated = jarFixture(
          id: 'kind-other',
          kind: JarKind.sinkingFund,
        );

        await repository.create(first);
        await repository.create(unrelated);
        await repository.create(archived);
        await repository.archive(archived.id, archivedAt);

        // When
        final jars = (await repository.getByKind(JarKind.reserve)).valueOrNull!;

        // Then
        expect(
          jars.map((jar) => jar.id),
          unorderedEquals([first.id, archived.id]),
        );
        expect(() => jars.clear(), throwsUnsupportedError);
      });

      test(
        'searches active and archived jars by normalized substring',
        () async {
          // Given
          final first = jarFixture(id: 'search-first', name: 'Holiday Fund');
          final archived = jarFixture(
            id: 'search-archived',
            name: 'Holiday House',
          );
          final unrelated = jarFixture(id: 'search-other', name: 'Emergency');

          await repository.create(first);
          await repository.create(unrelated);
          await repository.create(archived);
          await repository.archive(archived.id, archivedAt);

          // When
          final jars = (await repository.search('  LIDAY  ')).valueOrNull!;

          // Then
          expect(
            jars.map((jar) => jar.id),
            unorderedEquals([first.id, archived.id]),
          );
          expect(() => jars.clear(), throwsUnsupportedError);
        },
      );

      test('separates active and archived jars', () async {
        // Given
        final active = jarFixture(id: 'active-query');
        final archived = jarFixture(id: 'archived-query');

        await repository.create(active);
        await repository.create(archived);
        await repository.archive(archived.id, archivedAt);

        // When
        final activeResults = (await repository.getActive()).valueOrNull!;
        final archivedResults = (await repository.getArchived()).valueOrNull!;

        // Then
        expect(activeResults.map((jar) => jar.id), [active.id]);
        expect(archivedResults.map((jar) => jar.id), [archived.id]);

        expect(() => activeResults.clear(), throwsUnsupportedError);
        expect(() => archivedResults.clear(), throwsUnsupportedError);
      });
    });

    test('updates an archived jar', () async {
      // Given
      final original = jarFixture(id: 'update');

      await repository.create(original);
      await repository.archive(original.id, archivedAt);

      final replacement = jarFixture(
        id: original.id.value,
        name: 'Updated archived jar',
        archivedAt: archivedAt,
        modifiedAt: modifiedAt,
      );

      // When
      final result = await repository.update(replacement);

      // Then
      expect(result.isSuccess, isTrue);

      final stored = (await repository.getById(original.id)).valueOrNull!;

      expect(stored.name, 'Updated archived jar');
      expect(stored.archivedAt, archivedAt);
    });

    test('returns typed update failures', () async {
      // Given
      final original = jarFixture(id: 'update-original');
      await repository.create(original);

      // When
      final missing = await repository.update(jarFixture(id: 'update-missing'));
      final deleted = await repository.update(
        jarFixture(id: original.id.value, deletedAt: deletedAt),
      );

      // Then
      expect(missing.failureOrNull, isA<JarNotFoundFailure>());
      expect(deleted.failureOrNull, isA<JarAlreadyDeletedFailure>());
    });

    test('archives and unarchives using supplied timestamps', () async {
      // Given
      final jar = jarFixture(id: 'archive');
      await repository.create(jar);

      // When
      final archived = await repository.archive(jar.id, archivedAt);
      final unarchived = await repository.unarchive(jar.id, modifiedAt);

      // Then
      expect(archived.valueOrNull?.archivedAt, archivedAt);
      expect(archived.valueOrNull?.modifiedAt, archivedAt);

      expect(unarchived.valueOrNull?.archivedAt, isNull);
      expect(unarchived.valueOrNull?.modifiedAt, modifiedAt);
    });

    test('returns typed archival failures', () async {
      // Given
      final jar = jarFixture(id: 'transition');
      await repository.create(jar);

      // When
      final missing = await repository.archive(
        JarId.fromString('archive-missing'),
        archivedAt,
      );

      await repository.archive(jar.id, archivedAt);

      final alreadyArchived = await repository.archive(jar.id, archivedAt);

      await repository.unarchive(jar.id, modifiedAt);

      final notArchived = await repository.unarchive(jar.id, modifiedAt);

      // Then
      expect(missing.failureOrNull, isA<JarNotFoundFailure>());
      expect(alreadyArchived.failureOrNull, isA<JarAlreadyArchivedFailure>());
      expect(notArchived.failureOrNull, isA<JarNotArchivedFailure>());
    });

    test('physically deletes and restores an archived jar', () async {
      // Given
      final jar = jarFixture(id: 'delete-restore');

      await repository.create(jar);
      await repository.archive(jar.id, archivedAt);

      // When
      final deleteResult = await repository.delete(jar.id);

      // Then
      final deleted = deleteResult.valueOrNull!;

      expect(deleted.deletedAt, isNotNull);
      expect(deleted.archivedAt, archivedAt);
      expect((await repository.getById(jar.id)).valueOrNull, isNull);

      // When
      final restoreResult = await repository.restore(deleted);

      // Then
      expect(restoreResult.isSuccess, isTrue);

      final restored = (await repository.getById(jar.id)).valueOrNull!;

      expect(restored.deletedAt, isNull);
      expect(restored.archivedAt, archivedAt);
    });

    test('returns typed delete and restore failures', () async {
      // Given
      final active = jarFixture(id: 'restore-active');
      await repository.create(active);

      final duplicateDeleted = jarFixture(
        id: active.id.value,
        deletedAt: deletedAt,
      );

      // When
      final missingDelete = await repository.delete(
        JarId.fromString('delete-missing'),
      );
      final activeRestore = await repository.restore(active);
      final duplicateRestore = await repository.restore(duplicateDeleted);

      // Then
      expect(missingDelete.failureOrNull, isA<JarNotFoundFailure>());
      expect(activeRestore.failureOrNull, isA<JarNotDeletedFailure>());
      expect(duplicateRestore.failureOrNull, isA<JarAlreadyExistsFailure>());
    });

    test('translates malformed persisted jar to typed failure', () async {
      // Given
      const id = 'corrupt-jar';

      await SembastStores.jars.record(id).put(database, <String, Object?>{});

      // When
      final result = await repository.getById(JarId.fromString(id));

      // Then
      expect(result.failureOrNull, isA<JarRepositoryFailure>());
    });
  });
}
