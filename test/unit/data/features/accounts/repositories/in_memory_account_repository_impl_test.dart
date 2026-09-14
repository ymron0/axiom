@Tags(['data'])
library;

import 'package:axiom/src/core/domain/enums/entity_color.dart';
import 'package:axiom/src/core/domain/enums/entity_icon.dart';
import 'package:axiom/src/core/domain/value_objects/entity_logo.dart';
import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/custodian_id.dart';
import 'package:axiom/src/features/accounts/data/repositories/in_memory_account_repository_impl.dart';
import 'package:axiom/src/features/accounts/domain/entities/account.dart';
import 'package:axiom/src/features/accounts/domain/enums/account_kind.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_already_active_failure.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_already_archived_failure.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_already_deleted_failure.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_already_exists_failure.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_not_archived_failure.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_not_found_failure.dart';
import 'package:test/test.dart';

void main() {
  final createdAt = DateTime.utc(2026, 1, 1);
  final deletedAt = DateTime.utc(2026, 1, 2);

  Account accountFixture({
    required String id,
    String name = 'Account',
    String custodianId = 'custodian-bank',
    String denominationAssetId = 'asset-chf',
    AccountKind kind = AccountKind.checking,
    String? reference,
    EntityLogo? logo,
    EntityIcon icon = EntityIcon.accountBalance,
    EntityColor color = EntityColor.blue,
    int sortOrder = 0,
    DateTime? archivedAt,
    DateTime? deletedAt,
    DateTime? modifiedAt,
    int entityVersion = 1,
  }) {
    return Account(
      id: AccountId.fromString(id),
      name: name,
      custodianId: CustodianId.fromString(custodianId),
      denominationAssetId: AssetId.fromString(denominationAssetId),
      kind: kind,
      reference: reference,
      logo: logo,
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

  InMemoryAccountRepositoryImpl createRepository() {
    return InMemoryAccountRepositoryImpl(initialAccounts: const []);
  }

  group('InMemoryAccountRepositoryImpl', () {
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
        final repository = InMemoryAccountRepositoryImpl();

        // When
        final result = await repository.getAll();

        // Then
        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull, isNotEmpty);
      });

      test('copies supplied seed accounts in order', () async {
        // Given
        final first = accountFixture(id: 'seed-first');
        final second = accountFixture(id: 'seed-second');
        final seed = [first, second];
        final repository = InMemoryAccountRepositoryImpl(
          initialAccounts: seed,
        );
        seed.clear();

        // When
        final result = await repository.getAll();

        // Then
        expect(result.valueOrNull, [same(first), same(second)]);
      });

      test('rejects a deleted account in the supplied seed', () {
        // Given
        final account = accountFixture(
          id: 'seed-deleted',
          deletedAt: deletedAt,
        );

        // When
        InMemoryAccountRepositoryImpl createSeededRepository() {
          return InMemoryAccountRepositoryImpl(initialAccounts: [account]);
        }

        // Then
        expect(createSeededRepository, throwsArgumentError);
      });

      test('rejects duplicate account IDs in the supplied seed', () {
        // Given
        final first = accountFixture(id: 'seed-duplicate');
        final duplicate = accountFixture(
          id: first.id.value,
          name: 'Duplicate',
        );

        // When
        InMemoryAccountRepositoryImpl createSeededRepository() {
          return InMemoryAccountRepositoryImpl(
            initialAccounts: [first, duplicate],
          );
        }

        // Then
        expect(createSeededRepository, throwsArgumentError);
      });
    });

    group('create', () {
      test('stores an active account and preserves entity version', () async {
        // Given
        final repository = createRepository();
        final account = accountFixture(
          id: 'create-account',
          entityVersion: 7,
        );

        // When
        final result = await repository.create(account);

        // Then
        expect(result.isSuccess, isTrue);
        final stored = (await repository.getById(account.id)).valueOrNull;
        expect(stored, same(account));
        expect(stored!.entityVersion, 7);
      });

      test('rejects a duplicate ID without replacing the original', () async {
        // Given
        final repository = createRepository();
        final original = accountFixture(id: 'create-duplicate');
        final duplicate = accountFixture(
          id: original.id.value,
          name: 'Replacement',
        );
        await repository.create(original);

        // When
        final result = await repository.create(duplicate);

        // Then
        expect(result.failureOrNull, isA<AccountAlreadyExistsFailure>());
        expect(
          (await repository.getById(original.id)).valueOrNull,
          same(original),
        );
      });

      test('rejects a deleted account without storing it', () async {
        // Given
        final repository = createRepository();
        final account = accountFixture(
          id: 'create-deleted',
          deletedAt: deletedAt,
        );

        // When
        final result = await repository.create(account);

        // Then
        expect(result.failureOrNull, isA<AccountAlreadyDeletedFailure>());
        expect((await repository.getById(account.id)).valueOrNull, isNull);
      });

      test('rejects an archived account without storing it', () async {
        // Given
        final repository = createRepository();
        final archivedAt = DateTime.utc(2026, 1, 2);
        final account = accountFixture(
          id: 'create-archived',
          archivedAt: archivedAt,
          modifiedAt: archivedAt,
        );

        // When
        final result = await repository.create(account);

        // Then
        expect(result.failureOrNull, isA<AccountAlreadyArchivedFailure>());
        expect((await repository.getById(account.id)).valueOrNull, isNull);
      });
    });

    group('getAll', () {
      test('returns all accounts in insertion order', () async {
        // Given
        final repository = createRepository();
        final first = accountFixture(id: 'get-all-first');
        final second = accountFixture(id: 'get-all-second');
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
        final account = accountFixture(id: 'get-all-unmodifiable');
        await repository.create(account);

        // When
        final accounts = (await repository.getAll()).valueOrNull!;

        // Then
        expect(() => accounts.add(account), throwsUnsupportedError);
      });
    });

    group('getById', () {
      test('returns the account for an existing ID', () async {
        // Given
        final repository = createRepository();
        final account = accountFixture(id: 'get-by-id');
        await repository.create(account);

        // When
        final result = await repository.getById(account.id);

        // Then
        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull, same(account));
      });

      test('returns a successful null result for a missing ID', () async {
        // Given
        final repository = createRepository();

        // When
        final result = await repository.getById(
          AccountId.fromString('missing-account'),
        );

        // Then
        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull, isNull);
      });
    });

    group('getByCustodianId', () {
      test('returns matching accounts in storage order', () async {
        // Given
        final repository = createRepository();
        final first = accountFixture(
          id: 'custodian-first',
          custodianId: 'custodian-target',
        );
        final other = accountFixture(
          id: 'custodian-other',
          custodianId: 'custodian-other',
        );
        final second = accountFixture(
          id: 'custodian-second',
          custodianId: 'custodian-target',
        );
        await repository.create(first);
        await repository.create(other);
        await repository.create(second);

        // When
        final result = await repository.getByCustodianId(
          CustodianId.fromString('custodian-target'),
        );

        // Then
        expect(result.valueOrNull, [same(first), same(second)]);
      });

      test('returns immutable empty results when no account matches', () async {
        // Given
        final repository = createRepository();

        // When
        final accounts = (await repository.getByCustodianId(
          CustodianId.fromString('custodian-missing'),
        )).valueOrNull!;

        // Then
        expect(accounts, isEmpty);
        expect(
          () => accounts.add(accountFixture(id: 'custodian-unmodifiable')),
          throwsUnsupportedError,
        );
      });
    });

    group('search', () {
      test('matches names case-insensitively in storage order', () async {
        // Given
        final repository = createRepository();
        final first = accountFixture(
          id: 'search-first',
          name: 'Holiday Savings',
        );
        final second = accountFixture(
          id: 'search-second',
          name: 'Emergency savings',
        );
        final other = accountFixture(id: 'search-other', name: 'Checking');
        await repository.create(first);
        await repository.create(other);
        await repository.create(second);

        // When
        final result = await repository.search('SAVINGS');

        // Then
        expect(result.valueOrNull, [same(first), same(second)]);
      });

      test('returns an empty list when no name matches', () async {
        // Given
        final repository = createRepository();
        await repository.create(
          accountFixture(id: 'search-no-match', name: 'Checking'),
        );

        // When
        final result = await repository.search('savings');

        // Then
        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull, isEmpty);
      });

      test('returns an unmodifiable list', () async {
        // Given
        final repository = createRepository();
        final account = accountFixture(id: 'search-unmodifiable');
        await repository.create(account);

        // When
        final accounts = (await repository.search('account')).valueOrNull!;

        // Then
        expect(() => accounts.add(account), throwsUnsupportedError);
      });
    });

    group('update', () {
      test('replaces an account without changing entityVersion', () async {
        // Given
        final repository = createRepository();
        final original = accountFixture(
          id: 'update-account',
          entityVersion: 4,
        );
        final replacement = accountFixture(
          id: original.id.value,
          name: 'Updated account',
          custodianId: 'custodian-new',
          denominationAssetId: 'asset-eur',
          kind: AccountKind.savings,
          reference: 'CH12 3456',
          icon: EntityIcon.savings,
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

      test('rejects a missing account', () async {
        // Given
        final repository = createRepository();
        final missing = accountFixture(id: 'update-missing');

        // When
        final result = await repository.update(missing);

        // Then
        expect(result.failureOrNull, isA<AccountNotFoundFailure>());
        expect((await repository.getAll()).valueOrNull, isEmpty);
      });

      test('rejects a deleted account without mutation', () async {
        // Given
        final repository = createRepository();
        final original = accountFixture(id: 'update-deleted');
        final deleted = accountFixture(
          id: original.id.value,
          name: 'Deleted replacement',
          deletedAt: deletedAt,
        );
        await repository.create(original);

        // When
        final result = await repository.update(deleted);

        // Then
        expect(result.failureOrNull, isA<AccountAlreadyDeletedFailure>());
        expect(
          (await repository.getById(original.id)).valueOrNull,
          same(original),
        );
      });
    });

    group('archival', () {
      test(
        'archives an account and separates active and archived results',
        () async {
          // Given
          final repository = createRepository();
          final account = accountFixture(id: 'archive-account');
          final other = accountFixture(id: 'archive-other');
          final archivedAt = DateTime.utc(2026, 1, 2);
          await repository.create(account);
          await repository.create(other);

          // When
          final result = await repository.archive(account.id, archivedAt);

          // Then
          final archived = result.valueOrNull!;
          expect(archived.archivedAt, archivedAt);
          expect(archived.modifiedAt, archivedAt);
          expect(
            (await repository.getAll()).valueOrNull,
            [same(archived), same(other)],
          );
          final active = (await repository.getActive()).valueOrNull!;
          final archivedAccounts =
              (await repository.getArchived()).valueOrNull!;
          expect(active, [same(other)]);
          expect(archivedAccounts, [same(archived)]);
          expect(() => active.add(other), throwsUnsupportedError);
          expect(() => archivedAccounts.add(archived), throwsUnsupportedError);
        },
      );

      test('rejects missing and already archived accounts', () async {
        // Given
        final archivedAt = DateTime.utc(2026, 1, 2);
        final archived = accountFixture(
          id: 'archive-existing',
          archivedAt: archivedAt,
          modifiedAt: archivedAt,
        );
        final repository = InMemoryAccountRepositoryImpl(
          initialAccounts: [archived],
        );

        // When
        final missingResult = await repository.archive(
          AccountId.fromString('archive-missing'),
          archivedAt,
        );
        final existingResult = await repository.archive(
          archived.id,
          archivedAt,
        );

        // Then
        expect(missingResult.failureOrNull, isA<AccountNotFoundFailure>());
        expect(
          existingResult.failureOrNull,
          isA<AccountAlreadyArchivedFailure>(),
        );
      });

      test(
        'unarchives an account and updates its modification timestamp',
        () async {
          // Given
          final archivedAt = DateTime.utc(2026, 1, 2);
          final unarchivedAt = DateTime.utc(2026, 1, 3);
          final archived = accountFixture(
            id: 'unarchive-account',
            archivedAt: archivedAt,
            modifiedAt: archivedAt,
          );
          final repository = InMemoryAccountRepositoryImpl(
            initialAccounts: [archived],
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

      test('rejects missing and active accounts when unarchiving', () async {
        // Given
        final repository = createRepository();
        final modifiedAt = DateTime.utc(2026, 1, 2);
        final active = accountFixture(id: 'unarchive-active');
        await repository.create(active);

        // When
        final missingResult = await repository.unarchive(
          AccountId.fromString('unarchive-missing'),
          modifiedAt,
        );
        final activeResult = await repository.unarchive(active.id, modifiedAt);

        // Then
        expect(missingResult.failureOrNull, isA<AccountNotFoundFailure>());
        expect(activeResult.failureOrNull, isA<AccountNotArchivedFailure>());
      });
    });

    group('delete', () {
      test('removes the account and returns a deleted snapshot', () async {
        // Given
        final repository = createRepository();
        final logo = EntityLogo.asset('assets/bank.svg');
        final account = accountFixture(
          id: 'delete-account',
          name: 'Deleted account',
          custodianId: 'custodian-broker',
          denominationAssetId: 'asset-eur',
          kind: AccountKind.investment,
          reference: 'Portfolio 42',
          logo: logo,
          icon: EntityIcon.showChart,
          color: EntityColor.orange,
          sortOrder: 2,
          modifiedAt: DateTime.utc(2026, 1, 2),
          entityVersion: 9,
        );
        await repository.create(account);
        await repository.archive(account.id, DateTime.utc(2026, 1, 2));

        // When
        final result = await repository.delete(account.id);

        // Then
        final deleted = result.valueOrNull!;
        expect(deleted.id, account.id);
        expect(deleted.name, account.name);
        expect(deleted.custodianId, account.custodianId);
        expect(deleted.denominationAssetId, account.denominationAssetId);
        expect(deleted.kind, account.kind);
        expect(deleted.reference, account.reference);
        expect(deleted.logo, same(logo));
        expect(deleted.icon, account.icon);
        expect(deleted.color, account.color);
        expect(deleted.sortOrder, account.sortOrder);
        expect(deleted.createdAt, account.createdAt);
        expect(deleted.modifiedAt, account.modifiedAt);
        expect(deleted.entityVersion, 9);
        expect(deleted.archivedAt, DateTime.utc(2026, 1, 2));
        expect(deleted.deletedAt, isNotNull);
        expect(deleted.deletedAt!.isBefore(account.createdAt), isFalse);
        expect((await repository.getById(account.id)).valueOrNull, isNull);
      });

      test('rejects a missing account', () async {
        // Given
        final repository = createRepository();

        // When
        final result = await repository.delete(
          AccountId.fromString('delete-missing'),
        );

        // Then
        expect(result.failureOrNull, isA<AccountNotFoundFailure>());
      });
    });

    group('restore', () {
      test('stores an active copy of a deleted account', () async {
        // Given
        final repository = createRepository();
        final logo = EntityLogo.remote('https://example.com/logo.svg');
        final deleted = accountFixture(
          id: 'restore-account',
          name: 'Restored account',
          custodianId: 'custodian-wallet',
          denominationAssetId: 'asset-usd',
          kind: AccountKind.onlineWallet,
          reference: 'Wallet 8',
          logo: logo,
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
        expect(restored.custodianId, deleted.custodianId);
        expect(restored.denominationAssetId, deleted.denominationAssetId);
        expect(restored.kind, deleted.kind);
        expect(restored.reference, deleted.reference);
        expect(restored.logo, same(logo));
        expect(restored.icon, deleted.icon);
        expect(restored.color, deleted.color);
        expect(restored.sortOrder, deleted.sortOrder);
        expect(restored.createdAt, deleted.createdAt);
        expect(restored.modifiedAt, deleted.modifiedAt);
        expect(restored.entityVersion, 6);
        expect(restored.deletedAt, isNull);
        expect(restored.archivedAt, deletedAt);
      });

      test('rejects an active account without storing it', () async {
        // Given
        final repository = createRepository();
        final active = accountFixture(id: 'restore-active');

        // When
        final result = await repository.restore(active);

        // Then
        expect(result.failureOrNull, isA<AccountAlreadyActiveFailure>());
        expect((await repository.getById(active.id)).valueOrNull, isNull);
      });

      test('rejects an existing ID without mutation', () async {
        // Given
        final repository = createRepository();
        final original = accountFixture(id: 'restore-duplicate');
        final deleted = accountFixture(
          id: original.id.value,
          name: 'Deleted duplicate',
          deletedAt: deletedAt,
        );
        await repository.create(original);

        // When
        final result = await repository.restore(deleted);

        // Then
        expect(result.failureOrNull, isA<AccountAlreadyExistsFailure>());
        expect(
          (await repository.getById(original.id)).valueOrNull,
          same(original),
        );
      });
    });
  });
}
