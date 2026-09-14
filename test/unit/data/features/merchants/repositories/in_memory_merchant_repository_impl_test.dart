@Tags(['data'])
library;

import 'package:axiom/src/core/identity/ids/merchant_id.dart';
import 'package:axiom/src/features/merchants/data/repositories/in_memory_merchant_repository_impl.dart';
import 'package:axiom/src/features/merchants/domain/entities/merchant.dart';
import 'package:axiom/src/features/merchants/domain/failures/merchant_already_archived_failure.dart';
import 'package:axiom/src/features/merchants/domain/failures/merchant_already_active_failure.dart';
import 'package:axiom/src/features/merchants/domain/failures/merchant_already_deleted_failure.dart';
import 'package:axiom/src/features/merchants/domain/failures/merchant_already_exists_failure.dart';
import 'package:axiom/src/features/merchants/domain/failures/merchant_not_found_failure.dart';
import 'package:axiom/src/features/merchants/domain/failures/merchant_not_archived_failure.dart';
import 'package:test/test.dart';

void main() {
  final createdAt = DateTime.utc(2026, 1, 1);
  final deletedAt = DateTime.utc(2026, 1, 2);

  Merchant merchantFixture({
    required String id,
    String name = 'Merchant',
    DateTime? archivedAt,
    DateTime? deletedAt,
    DateTime? modifiedAt,
    int entityVersion = 1,
  }) {
    return Merchant(
      id: MerchantId.fromString(id),
      name: name,
      createdAt: createdAt,
      modifiedAt: modifiedAt ?? createdAt,
      archivedAt: archivedAt,
      deletedAt: deletedAt,
      entityVersion: entityVersion,
    );
  }

  InMemoryMerchantRepositoryImpl createRepository() {
    return InMemoryMerchantRepositoryImpl(initialMerchants: const []);
  }

  group('InMemoryMerchantRepositoryImpl', () {
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

      test('loads non-deleted external fixtures when no seed is supplied', () async {
        // Given
        final repository = InMemoryMerchantRepositoryImpl();

        // When
        final result = await repository.getAll();

        // Then
        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull, isNotEmpty);
        expect(
          result.valueOrNull!.every((merchant) => !merchant.isDeleted),
          isTrue,
        );
      });

      test('copies supplied seed merchants in order', () async {
        // Given
        final first = merchantFixture(id: 'seed-first');
        final second = merchantFixture(id: 'seed-second');
        final seed = [first, second];
        final repository = InMemoryMerchantRepositoryImpl(
          initialMerchants: seed,
        );
        seed.clear();

        // When
        final result = await repository.getAll();

        // Then
        expect(result.valueOrNull, [same(first), same(second)]);
      });

      test('rejects a deleted merchant in the supplied seed', () {
        // Given
        final merchant = merchantFixture(
          id: 'seed-deleted',
          deletedAt: deletedAt,
        );

        // When
        InMemoryMerchantRepositoryImpl createSeededRepository() {
          return InMemoryMerchantRepositoryImpl(initialMerchants: [merchant]);
        }

        // Then
        expect(createSeededRepository, throwsArgumentError);
      });

      test('rejects duplicate merchant IDs in the supplied seed', () {
        // Given
        final first = merchantFixture(id: 'seed-duplicate');
        final duplicate = merchantFixture(
          id: first.id.value,
          name: 'Duplicate',
        );

        // When
        InMemoryMerchantRepositoryImpl createSeededRepository() {
          return InMemoryMerchantRepositoryImpl(
            initialMerchants: [first, duplicate],
          );
        }

        // Then
        expect(createSeededRepository, throwsArgumentError);
      });
    });

    group('create', () {
      test('creates a merchant without changing entityVersion', () async {
          // Given
          final repository = createRepository();
          final merchant = merchantFixture(
            id: 'create-merchant',
            entityVersion: 7,
          );

          // When
          final result = await repository.create(merchant);

          // Then
          expect(result.isSuccess, isTrue);
          final stored = (await repository.getById(merchant.id)).valueOrNull;
          expect(stored, same(merchant));
          expect(stored!.entityVersion, 7);
      });

      test('rejects a duplicate ID without replacing the original', () async {
        // Given
        final repository = createRepository();
        final original = merchantFixture(id: 'create-duplicate');
        final duplicate = merchantFixture(
          id: original.id.value,
          name: 'Replacement',
        );
        await repository.create(original);

        // When
        final result = await repository.create(duplicate);

        // Then
        expect(result.failureOrNull, isA<MerchantAlreadyExistsFailure>());
        expect(
          (await repository.getById(original.id)).valueOrNull,
          same(original),
        );
      });

      test('rejects a deleted merchant without storing it', () async {
        // Given
        final repository = createRepository();
        final merchant = merchantFixture(
          id: 'create-deleted',
          deletedAt: deletedAt,
        );

        // When
        final result = await repository.create(merchant);

        // Then
        expect(result.failureOrNull, isA<MerchantAlreadyDeletedFailure>());
        expect((await repository.getById(merchant.id)).valueOrNull, isNull);
      });

      test('rejects an archived merchant without storing it', () async {
        // Given
        final repository = createRepository();
        final archivedAt = DateTime.utc(2026, 1, 2);
        final merchant = merchantFixture(
          id: 'create-archived',
          archivedAt: archivedAt,
          modifiedAt: archivedAt,
        );

        // When
        final result = await repository.create(merchant);

        // Then
        expect(result.failureOrNull, isA<MerchantAlreadyArchivedFailure>());
        expect((await repository.getById(merchant.id)).valueOrNull, isNull);
      });
    });

    group('getAll', () {
      test('returns all merchants in insertion order', () async {
        // Given
        final repository = createRepository();
        final first = merchantFixture(id: 'get-all-first');
        final second = merchantFixture(id: 'get-all-second');
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
        final merchant = merchantFixture(id: 'get-all-unmodifiable');
        await repository.create(merchant);

        // When
        final merchants = (await repository.getAll()).valueOrNull!;

        // Then
        expect(() => merchants.add(merchant), throwsUnsupportedError);
      });
    });

    group('archival', () {
      test('separates active and archived merchants without removing either', () async {
        // Given
        final active = merchantFixture(id: 'active');
        final archivedAt = DateTime.utc(2026, 1, 2);
        final archived = merchantFixture(
          id: 'archived',
          archivedAt: archivedAt,
          modifiedAt: archivedAt,
        );
        final repository = InMemoryMerchantRepositoryImpl(
          initialMerchants: [active, archived],
        );

        // When
        final activeMerchants = await repository.getActive();
        final archivedMerchants = await repository.getArchived();

        // Then
        expect(activeMerchants.valueOrNull, [same(active)]);
        expect(archivedMerchants.valueOrNull, [same(archived)]);
      });

      test('archives and unarchives a merchant with the supplied timestamps', () async {
        // Given
        final repository = createRepository();
        final merchant = merchantFixture(id: 'archive-transition');
        final archivedAt = DateTime.utc(2026, 1, 2);
        final unarchivedAt = DateTime.utc(2026, 1, 3);
        await repository.create(merchant);

        // When
        final archived = await repository.archive(merchant.id, archivedAt);
        final unarchived = await repository.unarchive(merchant.id, unarchivedAt);

        // Then
        expect(archived.valueOrNull?.archivedAt, archivedAt);
        expect(archived.valueOrNull?.modifiedAt, archivedAt);
        expect(unarchived.valueOrNull?.archivedAt, isNull);
        expect(unarchived.valueOrNull?.modifiedAt, unarchivedAt);
      });

      test('rejects archiving a missing merchant', () async {
        // Given
        final repository = createRepository();

        // When
        final result = await repository.archive(
          MerchantId.fromString('archive-missing'),
          DateTime.utc(2026, 1, 2),
        );

        // Then
        expect(result.failureOrNull, isA<MerchantNotFoundFailure>());
      });

      test('rejects archiving an already archived merchant', () async {
        // Given
        final archivedAt = DateTime.utc(2026, 1, 2);
        final merchant = merchantFixture(
          id: 'archive-already-archived',
          archivedAt: archivedAt,
          modifiedAt: archivedAt,
        );
        final repository = InMemoryMerchantRepositoryImpl(
          initialMerchants: [merchant],
        );

        // When
        final result = await repository.archive(merchant.id, archivedAt);

        // Then
        expect(result.failureOrNull, isA<MerchantAlreadyArchivedFailure>());
      });

      test('rejects unarchiving a missing merchant', () async {
        // Given
        final repository = createRepository();

        // When
        final result = await repository.unarchive(
          MerchantId.fromString('unarchive-missing'),
          DateTime.utc(2026, 1, 2),
        );

        // Then
        expect(result.failureOrNull, isA<MerchantNotFoundFailure>());
      });

      test('rejects unarchiving an active merchant', () async {
        // Given
        final repository = createRepository();
        final merchant = merchantFixture(id: 'unarchive-active');
        await repository.create(merchant);

        // When
        final result = await repository.unarchive(
          merchant.id,
          DateTime.utc(2026, 1, 2),
        );

        // Then
        expect(result.failureOrNull, isA<MerchantNotArchivedFailure>());
      });
    });

    group('getById', () {
      test('returns the merchant for an existing ID', () async {
        // Given
        final repository = createRepository();
        final merchant = merchantFixture(id: 'get-by-id');
        await repository.create(merchant);

        // When
        final result = await repository.getById(merchant.id);

        // Then
        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull, same(merchant));
      });

      test('returns a successful null result for a missing ID', () async {
        // Given
        final repository = createRepository();

        // When
        final result = await repository.getById(
          MerchantId.fromString('missing-merchant'),
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
        final first = merchantFixture(
          id: 'search-first',
          name: 'Corner Market',
        );
        final second = merchantFixture(
          id: 'search-second',
          name: 'Supermarket',
        );
        final other = merchantFixture(id: 'search-other', name: 'Bakery');
        await repository.create(first);
        await repository.create(other);
        await repository.create(second);

        // When
        final result = await repository.search('MARKET');

        // Then
        expect(result.valueOrNull, [same(first), same(second)]);
      });

      test('returns an empty list when no name matches', () async {
        // Given
        final repository = createRepository();
        await repository.create(
          merchantFixture(id: 'search-no-match', name: 'Bakery'),
        );

        // When
        final result = await repository.search('pharmacy');

        // Then
        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull, isEmpty);
      });

      test('returns an unmodifiable list', () async {
        // Given
        final repository = createRepository();
        final merchant = merchantFixture(id: 'search-unmodifiable');
        await repository.create(merchant);

        // When
        final merchants = (await repository.search('merchant')).valueOrNull!;

        // Then
        expect(() => merchants.add(merchant), throwsUnsupportedError);
      });
    });

    group('update', () {
      test('replaces a merchant without changing entityVersion', () async {
        // Given
        final repository = createRepository();
        final original = merchantFixture(
          id: 'update-merchant',
          entityVersion: 4,
        );
        final replacement = merchantFixture(
          id: original.id.value,
          name: 'Updated merchant',
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

      test('rejects a missing merchant', () async {
        // Given
        final repository = createRepository();
        final missing = merchantFixture(id: 'update-missing');

        // When
        final result = await repository.update(missing);

        // Then
        expect(result.failureOrNull, isA<MerchantNotFoundFailure>());
        expect((await repository.getAll()).valueOrNull, isEmpty);
      });

      test('rejects a deleted merchant without mutation', () async {
        // Given
        final repository = createRepository();
        final original = merchantFixture(id: 'update-deleted');
        final deleted = merchantFixture(
          id: original.id.value,
          name: 'Deleted replacement',
          deletedAt: deletedAt,
        );
        await repository.create(original);

        // When
        final result = await repository.update(deleted);

        // Then
        expect(result.failureOrNull, isA<MerchantAlreadyDeletedFailure>());
        expect(
          (await repository.getById(original.id)).valueOrNull,
          same(original),
        );
      });
    });

    group('delete', () {
      test('removes the merchant and returns a deleted snapshot', () async {
        // Given
        final repository = createRepository();
        final merchant = merchantFixture(
          id: 'delete-merchant',
          name: 'Deleted merchant',
          modifiedAt: DateTime.utc(2026, 1, 2),
          entityVersion: 9,
        );
        await repository.create(merchant);

        // When
        final result = await repository.delete(merchant.id);

        // Then
        final deleted = result.valueOrNull!;
        expect(deleted.id, merchant.id);
        expect(deleted.name, merchant.name);
        expect(deleted.createdAt, merchant.createdAt);
        expect(deleted.modifiedAt, merchant.modifiedAt);
        expect(deleted.entityVersion, 9);
        expect(deleted.deletedAt, isNotNull);
        expect(deleted.deletedAt!.isBefore(merchant.createdAt), isFalse);
        expect((await repository.getById(merchant.id)).valueOrNull, isNull);
      });

      test('rejects a missing merchant', () async {
        // Given
        final repository = createRepository();

        // When
        final result = await repository.delete(
          MerchantId.fromString('delete-missing'),
        );

        // Then
        expect(result.failureOrNull, isA<MerchantNotFoundFailure>());
      });
    });

    group('restore', () {
      test('stores an active copy of a deleted merchant', () async {
        // Given
        final repository = createRepository();
        final deleted = merchantFixture(
          id: 'restore-merchant',
          name: 'Restored merchant',
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
        expect(restored.createdAt, deleted.createdAt);
        expect(restored.modifiedAt, deleted.modifiedAt);
        expect(restored.entityVersion, 6);
        expect(restored.deletedAt, isNull);
      });

      test('rejects an active merchant without storing it', () async {
        // Given
        final repository = createRepository();
        final active = merchantFixture(id: 'restore-active');

        // When
        final result = await repository.restore(active);

        // Then
        expect(result.failureOrNull, isA<MerchantAlreadyActiveFailure>());
        expect((await repository.getById(active.id)).valueOrNull, isNull);
      });

      test('rejects an existing ID without mutation', () async {
        // Given
        final repository = createRepository();
        final original = merchantFixture(id: 'restore-duplicate');
        final deleted = merchantFixture(
          id: original.id.value,
          name: 'Deleted duplicate',
          deletedAt: deletedAt,
        );
        await repository.create(original);

        // When
        final result = await repository.restore(deleted);

        // Then
        expect(result.failureOrNull, isA<MerchantAlreadyExistsFailure>());
        expect(
          (await repository.getById(original.id)).valueOrNull,
          same(original),
        );
      });
    });
  });
}
