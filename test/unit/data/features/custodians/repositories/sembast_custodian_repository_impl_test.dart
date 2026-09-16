@Tags(['data', 'persistence'])
library;

import 'package:axiom/src/core/domain/enums/entity_color.dart';
import 'package:axiom/src/core/domain/enums/entity_icon.dart';
import 'package:axiom/src/core/identity/ids/custodian_id.dart';
import 'package:axiom/src/core/persistence/sembast_stores.dart';
import 'package:axiom/src/features/custodians/data/repositories/sembast_custodian_repository_impl.dart';
import 'package:axiom/src/features/custodians/domain/entities/custodian.dart';
import 'package:axiom/src/features/custodians/domain/enums/custodian_kind.dart';
import 'package:axiom/src/features/custodians/domain/failures/custodian_already_active_failure.dart';
import 'package:axiom/src/features/custodians/domain/failures/custodian_already_archived_failure.dart';
import 'package:axiom/src/features/custodians/domain/failures/custodian_already_deleted_failure.dart';
import 'package:axiom/src/features/custodians/domain/failures/custodian_already_exists_failure.dart';
import 'package:axiom/src/features/custodians/domain/failures/custodian_not_archived_failure.dart';
import 'package:axiom/src/features/custodians/domain/failures/custodian_not_found_failure.dart';
import 'package:axiom/src/features/custodians/domain/failures/custodian_persistence_failure.dart';
import 'package:axiom/src/features/custodians/domain/repositories/custodian_repository.dart';
import 'package:sembast/sembast.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/core/persistence/persistence_test_environment.dart';

void main() {
  late Database database;
  late CustodianRepository repository;

  final archivedAt = DateTime.utc(2026, 1, 2);
  final modifiedAt = DateTime.utc(2026, 1, 3);
  final deletedAt = DateTime.utc(2026, 1, 4);

  setUp(() async {
    final sembastDatabase = await createTestSembastDatabase();
    database = await sembastDatabase.open();

    repository = SembastCustodianRepositoryImpl(database: database);
  });

  group('SembastCustodianRepositoryImpl', () {
    test('persists and reads a custodian', () async {
      // Given
      final custodian = _custodian(id: 'create', name: 'Alpine Bank');

      // When
      final result = await repository.create(custodian);

      // Then
      expect(result.isSuccess, isTrue);

      final stored = (await repository.getById(custodian.id)).valueOrNull;

      expect(stored?.id, custodian.id);
      expect(stored?.name, custodian.name);
    });

    test('returns concrete failures for invalid create states', () async {
      // Given
      final active = _custodian(id: 'active');
      await repository.create(active);

      // When
      final duplicateResult = await repository.create(
        _custodian(id: active.id.value, name: 'Duplicate'),
      );
      final archivedResult = await repository.create(
        _custodian(id: 'archived-create', archivedAt: archivedAt),
      );
      final deletedResult = await repository.create(
        _custodian(id: 'deleted-create', deletedAt: deletedAt),
      );

      // Then
      expect(
        duplicateResult.failureOrNull,
        isA<CustodianAlreadyExistsFailure>(),
      );
      expect(
        archivedResult.failureOrNull,
        isA<CustodianAlreadyArchivedFailure>(),
      );
      expect(
        deletedResult.failureOrNull,
        isA<CustodianAlreadyDeletedFailure>(),
      );
    });

    test('returns all custodians in an immutable list', () async {
      // Given
      final first = _custodian(id: 'all-first');
      final second = _custodian(id: 'all-second');

      await repository.create(second);
      await repository.create(first);

      // When
      final custodians = (await repository.getAll()).valueOrNull!;

      // Then
      expect(
        custodians.map((custodian) => custodian.id),
        unorderedEquals([first.id, second.id]),
      );
      expect(() => custodians.clear(), throwsUnsupportedError);
    });

    test('returns successful null for a missing ID', () async {
      // When
      final result = await repository.getById(
        CustodianId.fromString('missing'),
      );

      // Then
      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull, isNull);
    });

    test('searches names case-insensitively', () async {
      // Given
      final first = _custodian(id: 'search-first', name: 'Alpine Bank');
      final second = _custodian(id: 'search-second', name: 'Riverbank');
      final unrelated = _custodian(id: 'search-other', name: 'Broker');

      await repository.create(first);
      await repository.create(unrelated);
      await repository.create(second);

      // When
      final custodians = (await repository.search('BANK')).valueOrNull!;

      // Then
      expect(
        custodians.map((custodian) => custodian.id),
        unorderedEquals([first.id, second.id]),
      );
      expect(() => custodians.clear(), throwsUnsupportedError);
    });

    test('separates active and archived custodians', () async {
      // Given
      final active = _custodian(id: 'active-query');
      final archived = _custodian(id: 'archived-query');

      await repository.create(active);
      await repository.create(archived);
      await repository.archive(archived.id, archivedAt);

      // When
      final activeResults = (await repository.getActive()).valueOrNull!;
      final archivedResults = (await repository.getArchived()).valueOrNull!;

      // Then
      expect(activeResults.map((custodian) => custodian.id), [active.id]);
      expect(archivedResults.map((custodian) => custodian.id), [archived.id]);

      expect(() => activeResults.clear(), throwsUnsupportedError);
      expect(() => archivedResults.clear(), throwsUnsupportedError);
    });

    test('updates an existing custodian', () async {
      // Given
      final original = _custodian(id: 'update', name: 'Original');
      final replacement = _custodian(
        id: original.id.value,
        name: 'Replacement',
        modifiedAt: modifiedAt,
      );

      await repository.create(original);

      // When
      final result = await repository.update(replacement);

      // Then
      expect(result.isSuccess, isTrue);
      expect(
        (await repository.getById(original.id)).valueOrNull?.name,
        'Replacement',
      );
    });

    test('returns typed update failures', () async {
      // Given
      final original = _custodian(id: 'update-original');
      await repository.create(original);

      // When
      final missing = await repository.update(_custodian(id: 'update-missing'));
      final deleted = await repository.update(
        _custodian(id: original.id.value, deletedAt: deletedAt),
      );

      // Then
      expect(missing.failureOrNull, isA<CustodianNotFoundFailure>());
      expect(deleted.failureOrNull, isA<CustodianAlreadyDeletedFailure>());
    });

    test('archives and unarchives using supplied timestamps', () async {
      // Given
      final custodian = _custodian(id: 'archive');
      await repository.create(custodian);

      // When
      final archived = await repository.archive(custodian.id, archivedAt);
      final unarchived = await repository.unarchive(custodian.id, modifiedAt);

      // Then
      expect(archived.valueOrNull?.archivedAt, archivedAt);
      expect(archived.valueOrNull?.modifiedAt, archivedAt);

      expect(unarchived.valueOrNull?.archivedAt, isNull);
      expect(unarchived.valueOrNull?.modifiedAt, modifiedAt);
    });

    test('returns typed archival failures', () async {
      // Given
      final custodian = _custodian(id: 'transition');
      await repository.create(custodian);

      // When
      final missing = await repository.archive(
        CustodianId.fromString('archive-missing'),
        archivedAt,
      );

      await repository.archive(custodian.id, archivedAt);

      final alreadyArchived = await repository.archive(
        custodian.id,
        archivedAt,
      );

      await repository.unarchive(custodian.id, modifiedAt);

      final notArchived = await repository.unarchive(custodian.id, modifiedAt);

      // Then
      expect(missing.failureOrNull, isA<CustodianNotFoundFailure>());
      expect(
        alreadyArchived.failureOrNull,
        isA<CustodianAlreadyArchivedFailure>(),
      );
      expect(notArchived.failureOrNull, isA<CustodianNotArchivedFailure>());
    });

    test('physically deletes and restores a custodian', () async {
      // Given
      final custodian = _custodian(id: 'delete-restore');

      await repository.create(custodian);
      await repository.archive(custodian.id, archivedAt);

      // When
      final deletedResult = await repository.delete(custodian.id);

      // Then
      final deleted = deletedResult.valueOrNull!;

      expect(deleted.deletedAt, isNotNull);
      expect(deleted.archivedAt, archivedAt);
      expect((await repository.getById(custodian.id)).valueOrNull, isNull);

      // When
      final restoreResult = await repository.restore(deleted);

      // Then
      expect(restoreResult.isSuccess, isTrue);

      final restored = (await repository.getById(custodian.id)).valueOrNull!;

      expect(restored.deletedAt, isNull);
      expect(restored.archivedAt, archivedAt);
    });

    test('returns typed delete and restore failures', () async {
      // Given
      final active = _custodian(id: 'restore-active');
      await repository.create(active);

      final duplicateDeleted = _custodian(
        id: active.id.value,
        deletedAt: deletedAt,
      );

      // When
      final missingDelete = await repository.delete(
        CustodianId.fromString('delete-missing'),
      );
      final activeRestore = await repository.restore(active);
      final duplicateRestore = await repository.restore(duplicateDeleted);

      // Then
      expect(missingDelete.failureOrNull, isA<CustodianNotFoundFailure>());
      expect(activeRestore.failureOrNull, isA<CustodianAlreadyActiveFailure>());
      expect(
        duplicateRestore.failureOrNull,
        isA<CustodianAlreadyExistsFailure>(),
      );
    });

    test('translates malformed persisted custodian to typed failure', () async {
      // Given
      const id = 'corrupt-custodian';

      await SembastStores.custodians
          .record(id)
          .put(database, <String, Object?>{});

      // When
      final result = await repository.getById(CustodianId.fromString(id));

      // Then
      expect(result.failureOrNull, isA<CustodianPersistenceFailure>());
    });
  });
}

Custodian _custodian({
  required String id,
  String name = 'Custodian',
  DateTime? archivedAt,
  DateTime? deletedAt,
  DateTime? modifiedAt,
  int entityVersion = 1,
}) {
  final createdAt = DateTime.utc(2026, 1, 1);

  return Custodian(
    id: CustodianId.fromString(id),
    name: name,
    kind: CustodianKind.bank,
    icon: EntityIcon.accountBalance,
    color: EntityColor.blue,
    sortOrder: 0,
    archivedAt: archivedAt,
    deletedAt: deletedAt,
    createdAt: createdAt,
    modifiedAt: modifiedAt ?? archivedAt ?? createdAt,
    entityVersion: entityVersion,
  );
}
