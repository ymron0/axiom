@Tags(['data', 'persistence'])
library;

import 'package:axiom/src/core/identity/ids/merchant_id.dart';
import 'package:axiom/src/core/persistence/sembast_stores.dart';
import 'package:axiom/src/features/merchants/data/repositories/sembast_merchant_repository_impl.dart';
import 'package:axiom/src/features/merchants/domain/failures/merchant_already_active_failure.dart';
import 'package:axiom/src/features/merchants/domain/failures/merchant_already_archived_failure.dart';
import 'package:axiom/src/features/merchants/domain/failures/merchant_already_deleted_failure.dart';
import 'package:axiom/src/features/merchants/domain/failures/merchant_already_exists_failure.dart';
import 'package:axiom/src/features/merchants/domain/failures/merchant_not_archived_failure.dart';
import 'package:axiom/src/features/merchants/domain/failures/merchant_not_found_failure.dart';
import 'package:axiom/src/features/merchants/data/failures/merchant_persistence_failure.dart';
import 'package:axiom/src/features/merchants/domain/repositories/merchant_repository.dart';
import 'package:sembast/sembast.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/core/persistence/persistence_test_environment.dart';
import '../../../../../fixtures/features/merchants/merchant_fixtures.dart';

void main() {
  late Database database;
  late MerchantRepository repository;

  final archivedAt = DateTime.utc(2026, 1, 2);
  final unarchivedAt = DateTime.utc(2026, 1, 3);
  final deletedAt = DateTime.utc(2026, 1, 4);

  setUp(() async {
    final sembastDatabase = await createTestSembastDatabase();
    database = await sembastDatabase.open();

    repository = SembastMerchantRepositoryImpl(database: database);
  });

  group('SembastMerchantRepositoryImpl', () {
    group('create', () {
      test('persists an active merchant', () async {
        // Given
        final merchant = merchantFixture(
          id: 'create-merchant',
          name: 'Corner Market',
        );

        // When
        final result = await repository.create(merchant);

        // Then
        expect(result.isSuccess, isTrue);

        final stored = (await repository.getById(merchant.id)).valueOrNull;
        expect(stored?.id, merchant.id);
        expect(stored?.name, merchant.name);
      });

      test('rejects duplicate, archived, and deleted states', () async {
        // Given
        final active = merchantFixture(id: 'create-active');
        await repository.create(active);

        final duplicate = merchantFixture(
          id: active.id.value,
          name: 'Replacement',
        );

        final archived = merchantFixture(
          id: 'create-archived',
          archivedAt: archivedAt,
          modifiedAt: archivedAt,
        );

        final deleted = merchantFixture(
          id: 'create-deleted',
          deletedAt: deletedAt,
        );

        // When
        final duplicateResult = await repository.create(duplicate);
        final archivedResult = await repository.create(archived);
        final deletedResult = await repository.create(deleted);

        // Then
        expect(
          duplicateResult.failureOrNull,
          isA<MerchantAlreadyExistsFailure>(),
        );
        expect(
          archivedResult.failureOrNull,
          isA<MerchantAlreadyArchivedFailure>(),
        );
        expect(
          deletedResult.failureOrNull,
          isA<MerchantAlreadyDeletedFailure>(),
        );
      });
    });

    group('queries', () {
      test('getAll returns all merchants through immutable list', () async {
        // Given
        final first = merchantFixture(id: 'all-first', name: 'First');
        final second = merchantFixture(id: 'all-second', name: 'Second');

        await repository.create(second);
        await repository.create(first);

        // When
        final merchants = (await repository.getAll()).valueOrNull!;

        // Then
        expect(
          merchants.map((merchant) => merchant.id),
          unorderedEquals([first.id, second.id]),
        );
        expect(() => merchants.clear(), throwsUnsupportedError);
      });

      test('getById returns null for missing merchant', () async {
        // When
        final result = await repository.getById(
          MerchantId.fromString('missing'),
        );

        // Then
        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull, isNull);
      });

      test('separates active and archived merchants', () async {
        // Given
        final first = merchantFixture(id: 'active');
        final second = merchantFixture(id: 'archived');

        await repository.create(first);
        await repository.create(second);
        await repository.archive(second.id, archivedAt);

        // When
        final active = (await repository.getActive()).valueOrNull!;
        final archived = (await repository.getArchived()).valueOrNull!;

        // Then
        expect(active.map((merchant) => merchant.id), [first.id]);
        expect(archived.map((merchant) => merchant.id), [second.id]);

        expect(() => active.clear(), throwsUnsupportedError);
        expect(() => archived.clear(), throwsUnsupportedError);
      });

      test('search is case-insensitive substring matching', () async {
        // Given
        final first = merchantFixture(
          id: 'search-first',
          name: 'Corner Market',
        );
        final second = merchantFixture(
          id: 'search-second',
          name: 'Supermarket',
        );
        final unrelated = merchantFixture(id: 'search-other', name: 'Bakery');

        await repository.create(first);
        await repository.create(unrelated);
        await repository.create(second);

        // When
        final result = await repository.search('MARKET');

        // Then
        final merchants = result.valueOrNull!;

        expect(
          merchants.map((merchant) => merchant.id),
          unorderedEquals([first.id, second.id]),
        );
        expect(() => merchants.clear(), throwsUnsupportedError);
      });
    });

    group('update', () {
      test('replaces existing snapshot', () async {
        // Given
        final original = merchantFixture(id: 'update', name: 'Original');
        final replacement = merchantFixture(
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

      test(
        'returns typed failures for missing and deleted snapshots',
        () async {
          // Given
          final original = merchantFixture(id: 'update-original');
          await repository.create(original);

          final deleted = merchantFixture(
            id: original.id.value,
            deletedAt: deletedAt,
          );

          // When
          final missingResult = await repository.update(
            merchantFixture(id: 'update-missing'),
          );
          final deletedResult = await repository.update(deleted);

          // Then
          expect(missingResult.failureOrNull, isA<MerchantNotFoundFailure>());
          expect(
            deletedResult.failureOrNull,
            isA<MerchantAlreadyDeletedFailure>(),
          );
        },
      );
    });

    group('archive and unarchive', () {
      test('persists both lifecycle transitions', () async {
        // Given
        final merchant = merchantFixture(id: 'archive');
        await repository.create(merchant);

        // When
        final archived = await repository.archive(merchant.id, archivedAt);
        final unarchived = await repository.unarchive(
          merchant.id,
          unarchivedAt,
        );

        // Then
        expect(archived.valueOrNull?.archivedAt, archivedAt);
        expect(archived.valueOrNull?.modifiedAt, archivedAt);

        expect(unarchived.valueOrNull?.archivedAt, isNull);
        expect(unarchived.valueOrNull?.modifiedAt, unarchivedAt);
      });

      test('returns typed failures for invalid archival transitions', () async {
        // Given
        final active = merchantFixture(id: 'active-transition');
        await repository.create(active);
        await repository.archive(active.id, archivedAt);

        // When
        final missingArchive = await repository.archive(
          MerchantId.fromString('archive-missing'),
          archivedAt,
        );
        final alreadyArchived = await repository.archive(active.id, archivedAt);

        await repository.unarchive(active.id, unarchivedAt);

        final activeUnarchive = await repository.unarchive(
          active.id,
          unarchivedAt,
        );

        // Then
        expect(missingArchive.failureOrNull, isA<MerchantNotFoundFailure>());
        expect(
          alreadyArchived.failureOrNull,
          isA<MerchantAlreadyArchivedFailure>(),
        );
        expect(
          activeUnarchive.failureOrNull,
          isA<MerchantNotArchivedFailure>(),
        );
      });
    });

    group('delete and restore', () {
      test(
        'physically removes and restores the caller-owned snapshot',
        () async {
          // Given
          final merchant = merchantFixture(id: 'delete-restore');

          await repository.create(merchant);
          await repository.archive(merchant.id, archivedAt);

          // When
          final deleteResult = await repository.delete(merchant.id);

          // Then
          final deleted = deleteResult.valueOrNull!;

          expect(deleted.id, merchant.id);
          expect(deleted.archivedAt, archivedAt);
          expect(deleted.deletedAt, isNotNull);
          expect((await repository.getById(merchant.id)).valueOrNull, isNull);

          // When
          final restoreResult = await repository.restore(deleted);

          // Then
          expect(restoreResult.isSuccess, isTrue);

          final restored = (await repository.getById(merchant.id)).valueOrNull!;

          expect(restored.deletedAt, isNull);
          expect(restored.archivedAt, archivedAt);
        },
      );

      test(
        'returns MerchantNotFoundFailure when deletion target is missing',
        () async {
          // When
          final result = await repository.delete(
            MerchantId.fromString('delete-missing'),
          );

          // Then
          expect(result.failureOrNull, isA<MerchantNotFoundFailure>());
        },
      );

      test('rejects restoring active or duplicate snapshots', () async {
        // Given
        final active = merchantFixture(id: 'restore-active');
        await repository.create(active);

        final deletedDuplicate = merchantFixture(
          id: active.id.value,
          deletedAt: deletedAt,
        );

        // When
        final activeResult = await repository.restore(active);
        final duplicateResult = await repository.restore(deletedDuplicate);

        // Then
        expect(activeResult.failureOrNull, isA<MerchantAlreadyActiveFailure>());
        expect(
          duplicateResult.failureOrNull,
          isA<MerchantAlreadyExistsFailure>(),
        );
      });
    });

    test('translates malformed persisted merchant to typed failure', () async {
      // Given
      const id = 'corrupt-merchant';

      await SembastStores.merchants
          .record(id)
          .put(database, <String, Object?>{});

      // When
      final result = await repository.getById(MerchantId.fromString(id));

      // Then
      expect(result.failureOrNull, isA<MerchantPersistenceFailure>());
    });
  });
}
