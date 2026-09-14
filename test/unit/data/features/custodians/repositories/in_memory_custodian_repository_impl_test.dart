@Tags(['data'])
library;

import 'package:axiom/src/core/domain/enums/entity_color.dart';
import 'package:axiom/src/core/domain/enums/entity_icon.dart';
import 'package:axiom/src/core/identity/ids/custodian_id.dart';
import 'package:axiom/src/features/custodians/data/repositories/in_memory_custodian_repository_impl.dart';
import 'package:axiom/src/features/custodians/domain/entities/custodian.dart';
import 'package:axiom/src/features/custodians/domain/enums/custodian_kind.dart';
import 'package:axiom/src/features/custodians/domain/failures/custodian_already_active_failure.dart';
import 'package:axiom/src/features/custodians/domain/failures/custodian_already_archived_failure.dart';
import 'package:axiom/src/features/custodians/domain/failures/custodian_already_deleted_failure.dart';
import 'package:axiom/src/features/custodians/domain/failures/custodian_already_exists_failure.dart';
import 'package:axiom/src/features/custodians/domain/failures/custodian_not_archived_failure.dart';
import 'package:axiom/src/features/custodians/domain/failures/custodian_not_found_failure.dart';
import 'package:test/test.dart';

void main() {
  final createdAt = DateTime.utc(2026, 1, 1);
  final deletedAt = DateTime.utc(2026, 1, 2);

  Custodian custodianFixture({
    required String id,
    String name = 'Custodian',
    CustodianKind kind = CustodianKind.bank,
    EntityIcon icon = EntityIcon.accountBalance,
    EntityColor color = EntityColor.blue,
    int sortOrder = 0,
    DateTime? archivedAt,
    DateTime? deletedAt,
    DateTime? modifiedAt,
    int entityVersion = 1,
  }) {
    return Custodian(
      id: CustodianId.fromString(id),
      name: name,
      kind: kind,
      icon: icon,
      color: color,
      sortOrder: sortOrder,
      archivedAt: archivedAt,
      deletedAt: deletedAt,
      createdAt: createdAt,
      modifiedAt: modifiedAt ?? createdAt,
      entityVersion: entityVersion,
    );
  }

  InMemoryCustodianRepositoryImpl createRepository() {
    return InMemoryCustodianRepositoryImpl(initialCustodians: const []);
  }

  group('InMemoryCustodianRepositoryImpl', () {
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

      test('loads external fixtures when no seed is supplied', () async {
        // Given
        final repository = InMemoryCustodianRepositoryImpl();

        // When
        final result = await repository.getAll();

        // Then
        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull, isNotEmpty);
      });

      test('copies supplied seed custodians in order', () async {
        // Given
        final first = custodianFixture(id: 'seed-first');
        final second = custodianFixture(id: 'seed-second');
        final seed = [first, second];
        final repository = InMemoryCustodianRepositoryImpl(
          initialCustodians: seed,
        );
        seed.clear();

        // When
        final result = await repository.getAll();

        // Then
        expect(result.valueOrNull, [same(first), same(second)]);
      });

      test('rejects a deleted custodian in the supplied seed', () {
        // Given
        final custodian = custodianFixture(
          id: 'seed-deleted',
          deletedAt: deletedAt,
        );

        // When
        InMemoryCustodianRepositoryImpl createSeededRepository() {
          return InMemoryCustodianRepositoryImpl(
            initialCustodians: [custodian],
          );
        }

        // Then
        expect(createSeededRepository, throwsArgumentError);
      });

      test('rejects duplicate custodian IDs in the supplied seed', () {
        // Given
        final first = custodianFixture(id: 'seed-duplicate');
        final duplicate = custodianFixture(
          id: first.id.value,
          name: 'Duplicate',
        );

        // When
        InMemoryCustodianRepositoryImpl createSeededRepository() {
          return InMemoryCustodianRepositoryImpl(
            initialCustodians: [first, duplicate],
          );
        }

        // Then
        expect(createSeededRepository, throwsArgumentError);
      });
    });

    group('create', () {
      test('stores an active custodian and preserves entity version', () async {
        // Given
        final repository = createRepository();
        final custodian = custodianFixture(
          id: 'create-custodian',
          entityVersion: 7,
        );

        // When
        final result = await repository.create(custodian);

        // Then
        expect(result.isSuccess, isTrue);
        final stored = (await repository.getById(custodian.id)).valueOrNull;
        expect(stored, same(custodian));
        expect(stored!.entityVersion, 7);
      });

      test('rejects a duplicate ID without replacing the original', () async {
        // Given
        final repository = createRepository();
        final original = custodianFixture(id: 'create-duplicate');
        final duplicate = custodianFixture(
          id: original.id.value,
          name: 'Replacement',
        );
        await repository.create(original);

        // When
        final result = await repository.create(duplicate);

        // Then
        expect(result.failureOrNull, isA<CustodianAlreadyExistsFailure>());
        expect(
          (await repository.getById(original.id)).valueOrNull,
          same(original),
        );
      });

      test('rejects a deleted custodian without storing it', () async {
        // Given
        final repository = createRepository();
        final custodian = custodianFixture(
          id: 'create-deleted',
          deletedAt: deletedAt,
        );

        // When
        final result = await repository.create(custodian);

        // Then
        expect(result.failureOrNull, isA<CustodianAlreadyDeletedFailure>());
        expect((await repository.getById(custodian.id)).valueOrNull, isNull);
      });

      test('rejects an archived custodian without storing it', () async {
        // Given
        final repository = createRepository();
        final archivedAt = DateTime.utc(2026, 1, 2);
        final custodian = custodianFixture(
          id: 'create-archived',
          archivedAt: archivedAt,
          modifiedAt: archivedAt,
        );

        // When
        final result = await repository.create(custodian);

        // Then
        expect(
          result.failureOrNull,
          isA<CustodianAlreadyArchivedFailure>(),
        );
        expect((await repository.getById(custodian.id)).valueOrNull, isNull);
      });
    });

    group('getAll', () {
      test('returns all custodians in insertion order', () async {
        // Given
        final repository = createRepository();
        final first = custodianFixture(id: 'get-all-first');
        final second = custodianFixture(id: 'get-all-second');
        await repository.create(second);
        await repository.create(first);

        // When
        final result = await repository.getAll();

        // Then
        expect(result.valueOrNull, [same(second), same(first)]);
      });

      test('returns an unmodifiable list', () async {
        // Given
        final repository = createRepository();
        final custodian = custodianFixture(id: 'get-all-unmodifiable');
        await repository.create(custodian);

        // When
        final custodians = (await repository.getAll()).valueOrNull!;

        // Then
        expect(() => custodians.add(custodian), throwsUnsupportedError);
      });
    });

    group('getById', () {
      test('returns the custodian for an existing ID', () async {
        // Given
        final repository = createRepository();
        final custodian = custodianFixture(id: 'get-by-id');
        await repository.create(custodian);

        // When
        final result = await repository.getById(custodian.id);

        // Then
        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull, same(custodian));
      });

      test('returns a successful null result for a missing ID', () async {
        // Given
        final repository = createRepository();

        // When
        final result = await repository.getById(
          CustodianId.fromString('missing-custodian'),
        );

        // Then
        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull, isNull);
      });
    });

    group('search', () {
      test('matches names case-insensitively in storage order', () async {
        // Given
        final repository = createRepository();
        final first = custodianFixture(
          id: 'search-first',
          name: 'Alpine Bank',
        );
        final second = custodianFixture(
          id: 'search-second',
          name: 'Riverbank',
        );
        final other = custodianFixture(id: 'search-other', name: 'Broker');
        await repository.create(first);
        await repository.create(other);
        await repository.create(second);

        // When
        final result = await repository.search('BANK');

        // Then
        expect(result.valueOrNull, [same(first), same(second)]);
      });

      test('returns an empty list when no name matches', () async {
        // Given
        final repository = createRepository();
        await repository.create(
          custodianFixture(id: 'search-no-match', name: 'Broker'),
        );

        // When
        final result = await repository.search('bank');

        // Then
        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull, isEmpty);
      });

      test('returns an unmodifiable list', () async {
        // Given
        final repository = createRepository();
        final custodian = custodianFixture(id: 'search-unmodifiable');
        await repository.create(custodian);

        // When
        final custodians = (await repository.search('custodian')).valueOrNull!;

        // Then
        expect(() => custodians.add(custodian), throwsUnsupportedError);
      });
    });

    group('update', () {
      test('replaces a custodian without changing entityVersion', () async {
        // Given
        final repository = createRepository();
        final original = custodianFixture(
          id: 'update-custodian',
          entityVersion: 4,
        );
        final replacement = custodianFixture(
          id: original.id.value,
          name: 'Updated custodian',
          kind: CustodianKind.broker,
          icon: EntityIcon.showChart,
          color: EntityColor.green,
          sortOrder: 3,
          modifiedAt: DateTime.utc(2026, 1, 3),
          entityVersion: original.entityVersion,
        );
        await repository.create(original);

        // When
        final result = await repository.update(replacement);

        // Then
        expect(result.isSuccess, isTrue);
        final stored = (await repository.getById(original.id)).valueOrNull;
        expect(stored, same(replacement));
        expect(stored!.entityVersion, 4);
      });

      test('rejects a missing custodian', () async {
        // Given
        final repository = createRepository();
        final missing = custodianFixture(id: 'update-missing');

        // When
        final result = await repository.update(missing);

        // Then
        expect(result.failureOrNull, isA<CustodianNotFoundFailure>());
        expect((await repository.getAll()).valueOrNull, isEmpty);
      });

      test('rejects a deleted custodian without mutation', () async {
        // Given
        final repository = createRepository();
        final original = custodianFixture(id: 'update-deleted');
        final deleted = custodianFixture(
          id: original.id.value,
          name: 'Deleted replacement',
          deletedAt: deletedAt,
        );
        await repository.create(original);

        // When
        final result = await repository.update(deleted);

        // Then
        expect(result.failureOrNull, isA<CustodianAlreadyDeletedFailure>());
        expect(
          (await repository.getById(original.id)).valueOrNull,
          same(original),
        );
      });
    });

    group('archival', () {
      test(
        'archives a custodian and separates active and archived results',
        () async {
          // Given
          final repository = createRepository();
          final custodian = custodianFixture(id: 'archive-custodian');
          final other = custodianFixture(id: 'archive-other');
          final archivedAt = DateTime.utc(2026, 1, 2);
          await repository.create(custodian);
          await repository.create(other);

          // When
          final result = await repository.archive(custodian.id, archivedAt);

          // Then
          final archived = result.valueOrNull!;
          expect(archived.archivedAt, archivedAt);
          expect(archived.modifiedAt, archivedAt);
          expect(
            (await repository.getAll()).valueOrNull,
            [same(archived), same(other)],
          );
          final active = (await repository.getActive()).valueOrNull!;
          final archivedCustodians =
              (await repository.getArchived()).valueOrNull!;
          expect(active, [same(other)]);
          expect(archivedCustodians, [same(archived)]);
          expect(() => active.add(other), throwsUnsupportedError);
          expect(
            () => archivedCustodians.add(archived),
            throwsUnsupportedError,
          );
        },
      );

      test('rejects missing and already archived custodians', () async {
        // Given
        final archivedAt = DateTime.utc(2026, 1, 2);
        final archived = custodianFixture(
          id: 'archive-existing',
          archivedAt: archivedAt,
          modifiedAt: archivedAt,
        );
        final repository = InMemoryCustodianRepositoryImpl(
          initialCustodians: [archived],
        );

        // When
        final missingResult = await repository.archive(
          CustodianId.fromString('archive-missing'),
          archivedAt,
        );
        final existingResult = await repository.archive(
          archived.id,
          archivedAt,
        );

        // Then
        expect(missingResult.failureOrNull, isA<CustodianNotFoundFailure>());
        expect(
          existingResult.failureOrNull,
          isA<CustodianAlreadyArchivedFailure>(),
        );
      });

      test(
        'unarchives a custodian and updates its modification timestamp',
        () async {
          // Given
          final archivedAt = DateTime.utc(2026, 1, 2);
          final unarchivedAt = DateTime.utc(2026, 1, 3);
          final archived = custodianFixture(
            id: 'unarchive-custodian',
            archivedAt: archivedAt,
            modifiedAt: archivedAt,
          );
          final repository = InMemoryCustodianRepositoryImpl(
            initialCustodians: [archived],
          );

          // When
          final result = await repository.unarchive(
            archived.id,
            unarchivedAt,
          );

          // Then
          final unarchived = result.valueOrNull!;
          expect(unarchived.archivedAt, isNull);
          expect(unarchived.modifiedAt, unarchivedAt);
          expect((await repository.getActive()).valueOrNull, [same(unarchived)]);
          expect((await repository.getArchived()).valueOrNull, isEmpty);
        },
      );

      test('rejects missing and active custodians when unarchiving', () async {
        // Given
        final repository = createRepository();
        final modifiedAt = DateTime.utc(2026, 1, 2);
        final active = custodianFixture(id: 'unarchive-active');
        await repository.create(active);

        // When
        final missingResult = await repository.unarchive(
          CustodianId.fromString('unarchive-missing'),
          modifiedAt,
        );
        final activeResult = await repository.unarchive(active.id, modifiedAt);

        // Then
        expect(missingResult.failureOrNull, isA<CustodianNotFoundFailure>());
        expect(
          activeResult.failureOrNull,
          isA<CustodianNotArchivedFailure>(),
        );
      });
    });

    group('delete', () {
      test('removes the custodian and returns a deleted snapshot', () async {
        // Given
        final repository = createRepository();
        final custodian = custodianFixture(
          id: 'delete-custodian',
          name: 'Deleted custodian',
          kind: CustodianKind.exchange,
          icon: EntityIcon.currencyExchange,
          color: EntityColor.orange,
          sortOrder: 2,
          modifiedAt: DateTime.utc(2026, 1, 2),
          entityVersion: 9,
        );
        await repository.create(custodian);
        await repository.archive(custodian.id, DateTime.utc(2026, 1, 2));

        // When
        final result = await repository.delete(custodian.id);

        // Then
        final deleted = result.valueOrNull!;
        expect(deleted.id, custodian.id);
        expect(deleted.name, custodian.name);
        expect(deleted.kind, custodian.kind);
        expect(deleted.icon, custodian.icon);
        expect(deleted.color, custodian.color);
        expect(deleted.sortOrder, custodian.sortOrder);
        expect(deleted.createdAt, custodian.createdAt);
        expect(deleted.modifiedAt, custodian.modifiedAt);
        expect(deleted.entityVersion, 9);
        expect(deleted.archivedAt, DateTime.utc(2026, 1, 2));
        expect(deleted.deletedAt, isNotNull);
        expect(deleted.deletedAt!.isBefore(custodian.createdAt), isFalse);
        expect((await repository.getById(custodian.id)).valueOrNull, isNull);
      });

      test('rejects a missing custodian', () async {
        // Given
        final repository = createRepository();

        // When
        final result = await repository.delete(
          CustodianId.fromString('delete-missing'),
        );

        // Then
        expect(result.failureOrNull, isA<CustodianNotFoundFailure>());
      });
    });

    group('restore', () {
      test('stores an active copy of a deleted custodian', () async {
        // Given
        final repository = createRepository();
        final deleted = custodianFixture(
          id: 'restore-custodian',
          name: 'Restored custodian',
          kind: CustodianKind.selfCustody,
          icon: EntityIcon.wallet,
          color: EntityColor.purple,
          sortOrder: 4,
          archivedAt: deletedAt,
          deletedAt: deletedAt,
          modifiedAt: DateTime.utc(2026, 1, 2),
          entityVersion: 6,
        );

        // When
        final result = await repository.restore(deleted);

        // Then
        expect(result.isSuccess, isTrue);
        final restored = (await repository.getById(deleted.id)).valueOrNull!;
        expect(restored.id, deleted.id);
        expect(restored.name, deleted.name);
        expect(restored.kind, deleted.kind);
        expect(restored.icon, deleted.icon);
        expect(restored.color, deleted.color);
        expect(restored.sortOrder, deleted.sortOrder);
        expect(restored.createdAt, deleted.createdAt);
        expect(restored.modifiedAt, deleted.modifiedAt);
        expect(restored.entityVersion, 6);
        expect(restored.deletedAt, isNull);
        expect(restored.archivedAt, deletedAt);
      });

      test('rejects an active custodian without storing it', () async {
        // Given
        final repository = createRepository();
        final active = custodianFixture(id: 'restore-active');

        // When
        final result = await repository.restore(active);

        // Then
        expect(result.failureOrNull, isA<CustodianAlreadyActiveFailure>());
        expect((await repository.getById(active.id)).valueOrNull, isNull);
      });

      test('rejects an existing ID without mutation', () async {
        // Given
        final repository = createRepository();
        final original = custodianFixture(id: 'restore-duplicate');
        final deleted = custodianFixture(
          id: original.id.value,
          name: 'Deleted duplicate',
          deletedAt: deletedAt,
        );
        await repository.create(original);

        // When
        final result = await repository.restore(deleted);

        // Then
        expect(result.failureOrNull, isA<CustodianAlreadyExistsFailure>());
        expect(
          (await repository.getById(original.id)).valueOrNull,
          same(original),
        );
      });
    });
  });
}
