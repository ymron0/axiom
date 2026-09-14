import 'package:axiom/src/core/identity/ids/jar_id.dart';
import 'package:axiom/src/features/jars/data/repositories/in_memory_jar_repository_impl.dart';
import 'package:axiom/src/features/jars/domain/enums/jar_kind.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_already_archived_failure.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_already_deleted_failure.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_already_exists_failure.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_not_archived_failure.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_not_deleted_failure.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_not_found_failure.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/features/jars/jar_fixtures.dart';


void main() {
  final archivedAt = DateTime.utc(2026, 1, 2);
  final deletedAt = DateTime.utc(2026, 1, 3);

  InMemoryJarRepositoryImpl createRepository() {
    return InMemoryJarRepositoryImpl(initialJars: const []);
  }

  group('InMemoryJarRepositoryImpl', () {
    group('constructor', () {
      test('starts empty when supplied an empty seed', () async {
        // Given
        final repository = createRepository();

        // When
        final result = await repository.getAll();

        // Then
        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull, isEmpty);
      });

      test('stores active and archived seed jars in order', () async {
        // Given
        final active = jarFixture(id: 'seed-active');
        final archived = jarFixture(
          id: 'seed-archived',
          archivedAt: archivedAt,
        );
        final repository = InMemoryJarRepositoryImpl(
          initialJars: [active, archived],
        );

        // When
        final result = await repository.getAll();

        // Then
        expect(result.valueOrNull, [same(active), same(archived)]);
      });

      test('rejects a deleted jar in the supplied seed', () {
        // Given
        final deleted = jarFixture(id: 'seed-deleted', deletedAt: deletedAt);

        // When / Then
        expect(
          () => InMemoryJarRepositoryImpl(initialJars: [deleted]),
          throwsArgumentError,
        );
      });

      test('rejects duplicate jar IDs in the supplied seed', () {
        // Given
        final first = jarFixture(id: 'seed-duplicate');
        final duplicate = jarFixture(id: first.id.value, name: 'Duplicate');

        // When / Then
        expect(
          () => InMemoryJarRepositoryImpl(initialJars: [first, duplicate]),
          throwsArgumentError,
        );
      });
    });

    group('create', () {
      test('stores an active jar without changing its entity version', () async {
        // Given
        final repository = createRepository();
        final jar = jarFixture(id: 'create-jar');

        // When
        final result = await repository.create(jar);

        // Then
        expect(result.isSuccess, isTrue);
        expect((await repository.getById(jar.id)).valueOrNull, same(jar));
      });

      test('rejects a duplicate identity without replacing the original', () async {
        // Given
        final repository = createRepository();
        final original = jarFixture(id: 'create-duplicate');
        final duplicate = jarFixture(
          id: original.id.value,
          name: 'Replacement',
        );
        await repository.create(original);

        // When
        final result = await repository.create(duplicate);

        // Then
        expect(result.failureOrNull, isA<JarAlreadyExistsFailure>());
        expect(
          (await repository.getById(original.id)).valueOrNull,
          same(original),
        );
      });

      test('rejects archived and deleted jars without storing either', () async {
        // Given
        final repository = createRepository();
        final archived = jarFixture(
          id: 'create-archived',
          archivedAt: archivedAt,
        );
        final deleted = jarFixture(
          id: 'create-deleted',
          deletedAt: deletedAt,
        );

        // When
        final archivedResult = await repository.create(archived);
        final deletedResult = await repository.create(deleted);

        // Then
        expect(archivedResult.failureOrNull, isA<JarAlreadyArchivedFailure>());
        expect(deletedResult.failureOrNull, isA<JarAlreadyDeletedFailure>());
        expect((await repository.getAll()).valueOrNull, isEmpty);
      });
    });

    group('queries', () {
      test('returns all jars in insertion order through an unmodifiable list',
          () async {
        // Given
        final repository = createRepository();
        final first = jarFixture(id: 'all-first');
        final second = jarFixture(id: 'all-second');
        await repository.create(second);
        await repository.create(first);

        // When
        final jars = (await repository.getAll()).valueOrNull!;

        // Then
        expect(jars, [same(second), same(first)]);
        expect(() => jars.add(first), throwsUnsupportedError);
      });

      test('returns a jar or successful null by ID', () async {
        // Given
        final repository = createRepository();
        final jar = jarFixture(id: 'by-id');
        await repository.create(jar);

        // When
        final found = await repository.getById(jar.id);
        final missing = await repository.getById(JarId.fromString('missing'));

        // Then
        expect(found.valueOrNull, same(jar));
        expect(missing.isSuccess, isTrue);
        expect(missing.valueOrNull, isNull);
      });

      test('separates active and archived jars', () async {
        // Given
        final active = jarFixture(id: 'active');
        final archived = jarFixture(id: 'archived', archivedAt: archivedAt);
        final repository = InMemoryJarRepositoryImpl(
          initialJars: [active, archived],
        );

        // When
        final activeJars = (await repository.getActive()).valueOrNull!;
        final archivedJars = (await repository.getArchived()).valueOrNull!;

        // Then
        expect(activeJars, [same(active)]);
        expect(archivedJars, [same(archived)]);
        expect(() => activeJars.add(active), throwsUnsupportedError);
        expect(() => archivedJars.add(archived), throwsUnsupportedError);
      });

      test('filters active and archived jars by kind in storage order',
          () async {
        // Given
        final first = jarFixture(id: 'kind-first', kind: JarKind.reserve);
        final archived = jarFixture(
          id: 'kind-archived',
          kind: JarKind.reserve,
          archivedAt: archivedAt,
        );
        final other = jarFixture(
          id: 'kind-other',
          kind: JarKind.sinkingFund,
        );
        final repository = InMemoryJarRepositoryImpl(
          initialJars: [first, other, archived],
        );

        // When
        final jars = (await repository.getByKind(JarKind.reserve)).valueOrNull!;

        // Then
        expect(jars, [same(first), same(archived)]);
        expect(() => jars.add(first), throwsUnsupportedError);
      });

      test('searches active and archived names case-insensitively by substring',
          () async {
        // Given
        final first = jarFixture(id: 'search-first', name: 'Holiday Fund');
        final archived = jarFixture(
          id: 'search-archived',
          name: 'holiday house',
          archivedAt: archivedAt,
        );
        final other = jarFixture(id: 'search-other', name: 'Emergency');
        final repository = InMemoryJarRepositoryImpl(
          initialJars: [first, other, archived],
        );

        // When
        final jars = (await repository.search('  LIDAY  ')).valueOrNull!;

        // Then
        expect(jars, [same(first), same(archived)]);
        expect(() => jars.add(first), throwsUnsupportedError);
      });
    });

    group('update', () {
      test('replaces an existing archived jar', () async {
        // Given
        final original = jarFixture(id: 'update', archivedAt: archivedAt);
        final replacement = jarFixture(
          id: original.id.value,
          name: 'Updated jar',
          archivedAt: archivedAt,
          modifiedAt: DateTime.utc(2026, 1, 4),
        );
        final repository = InMemoryJarRepositoryImpl(initialJars: [original]);

        // When
        final result = await repository.update(replacement);

        // Then
        expect(result.isSuccess, isTrue);
        expect(
          (await repository.getById(original.id)).valueOrNull,
          same(replacement),
        );
      });

      test('rejects a missing or deleted jar without mutation', () async {
        // Given
        final original = jarFixture(id: 'update-original');
        final deleted = jarFixture(
          id: original.id.value,
          deletedAt: deletedAt,
        );
        final repository = InMemoryJarRepositoryImpl(initialJars: [original]);

        // When
        final missingResult = await repository.update(jarFixture(id: 'missing'));
        final deletedResult = await repository.update(deleted);

        // Then
        expect(missingResult.failureOrNull, isA<JarNotFoundFailure>());
        expect(deletedResult.failureOrNull, isA<JarAlreadyDeletedFailure>());
        expect(
          (await repository.getById(original.id)).valueOrNull,
          same(original),
        );
      });
    });

    group('archive and unarchive', () {
      test('archives a jar and records the supplied archive time as modified',
          () async {
        // Given
        final jar = jarFixture(id: 'archive');
        final repository = InMemoryJarRepositoryImpl(initialJars: [jar]);

        // When
        final result = await repository.archive(jar.id, archivedAt);

        // Then
        final archived = result.valueOrNull!;
        expect(archived.id, jar.id);
        expect(archived.name, jar.name);
        expect(archived.archivedAt, archivedAt);
        expect(archived.modifiedAt, archivedAt);
        expect((await repository.getById(jar.id)).valueOrNull, same(archived));
      });

      test('rejects a missing or already archived jar', () async {
        // Given
        final archived = jarFixture(id: 'already-archived', archivedAt: archivedAt);
        final repository = InMemoryJarRepositoryImpl(initialJars: [archived]);

        // When
        final missingResult = await repository.archive(
          JarId.fromString('missing'),
          archivedAt,
        );
        final archivedResult = await repository.archive(archived.id, archivedAt);

        // Then
        expect(missingResult.failureOrNull, isA<JarNotFoundFailure>());
        expect(archivedResult.failureOrNull, isA<JarAlreadyArchivedFailure>());
      });

      test('unarchives a jar and records the supplied modification time',
          () async {
        // Given
        final jar = jarFixture(id: 'unarchive', archivedAt: archivedAt);
        final modifiedAt = DateTime.utc(2026, 1, 4);
        final repository = InMemoryJarRepositoryImpl(initialJars: [jar]);

        // When
        final result = await repository.unarchive(jar.id, modifiedAt);

        // Then
        final unarchived = result.valueOrNull!;
        expect(unarchived.id, jar.id);
        expect(unarchived.archivedAt, isNull);
        expect(unarchived.modifiedAt, modifiedAt);
        expect(
          (await repository.getById(jar.id)).valueOrNull,
          same(unarchived),
        );
      });

      test('rejects a missing or active jar when unarchiving', () async {
        // Given
        final active = jarFixture(id: 'active');
        final repository = InMemoryJarRepositoryImpl(initialJars: [active]);

        // When
        final missingResult = await repository.unarchive(
          JarId.fromString('missing'),
          archivedAt,
        );
        final activeResult = await repository.unarchive(active.id, archivedAt);

        // Then
        expect(missingResult.failureOrNull, isA<JarNotFoundFailure>());
        expect(activeResult.failureOrNull, isA<JarNotArchivedFailure>());
      });
    });

    group('delete and restore', () {
      test('removes a jar and returns a deleted snapshot', () async {
        // Given
        final jar = jarFixture(id: 'delete', archivedAt: archivedAt);
        final repository = InMemoryJarRepositoryImpl(initialJars: [jar]);

        // When
        final result = await repository.delete(jar.id);

        // Then
        final deleted = result.valueOrNull!;
        expect(deleted.id, jar.id);
        expect(deleted.archivedAt, archivedAt);
        expect(deleted.deletedAt, isNotNull);
        expect((await repository.getById(jar.id)).valueOrNull, isNull);
      });

      test('rejects deletion of a missing jar', () async {
        // Given
        final repository = createRepository();

        // When
        final result = await repository.delete(JarId.fromString('missing'));

        // Then
        expect(result.failureOrNull, isA<JarNotFoundFailure>());
      });

      test('restores a deleted archived jar while retaining its archival state',
          () async {
        // Given
        final deleted = jarFixture(
          id: 'restore',
          archivedAt: archivedAt,
          deletedAt: deletedAt,
        );
        final repository = createRepository();

        // When
        final result = await repository.restore(deleted);

        // Then
        final restored = (await repository.getById(deleted.id)).valueOrNull!;
        expect(result.isSuccess, isTrue);
        expect(restored.archivedAt, archivedAt);
        expect(restored.deletedAt, isNull);
      });

      test('rejects an active or duplicate deleted jar without mutation',
          () async {
        // Given
        final active = jarFixture(id: 'restore-active');
        final duplicateDeleted = jarFixture(
          id: active.id.value,
          deletedAt: deletedAt,
        );
        final repository = InMemoryJarRepositoryImpl(initialJars: [active]);

        // When
        final activeResult = await repository.restore(active);
        final duplicateResult = await repository.restore(duplicateDeleted);

        // Then
        expect(activeResult.failureOrNull, isA<JarNotDeletedFailure>());
        expect(duplicateResult.failureOrNull, isA<JarAlreadyExistsFailure>());
        expect(
          (await repository.getById(active.id)).valueOrNull,
          same(active),
        );
      });
    });
  });
}
