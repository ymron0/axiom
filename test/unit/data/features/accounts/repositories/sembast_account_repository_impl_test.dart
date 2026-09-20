@Tags(['data', 'persistence'])
library;

import 'package:axiom/src/core/domain/enums/entity_color.dart';
import 'package:axiom/src/core/domain/enums/entity_icon.dart';
import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/custodian_id.dart';
import 'package:axiom/src/core/persistence/sembast_stores.dart';
import 'package:axiom/src/features/accounts/data/repositories/sembast_account_repository_impl.dart';
import 'package:axiom/src/features/accounts/domain/entities/account.dart';
import 'package:axiom/src/features/accounts/domain/enums/account_kind.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_already_active_failure.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_already_archived_failure.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_already_deleted_failure.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_already_exists_failure.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_not_archived_failure.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_not_found_failure.dart';
import 'package:axiom/src/features/accounts/data/failures/account_persistence_failure.dart';
import 'package:axiom/src/features/accounts/domain/repositories/account_repository.dart';
import 'package:sembast/sembast.dart';
import 'package:test/test.dart';

import '../../../../../fixtures/core/persistence/persistence_test_environment.dart';

void main() {
  late Database database;
  late AccountRepository repository;

  final archivedAt = DateTime.utc(2026, 1, 2);
  final modifiedAt = DateTime.utc(2026, 1, 3);
  final deletedAt = DateTime.utc(2026, 1, 4);

  setUp(() async {
    final sembastDatabase = await createTestSembastDatabase();
    database = await sembastDatabase.open();

    repository = SembastAccountRepositoryImpl(database: database);
  });

  group('SembastAccountRepositoryImpl', () {
    group('create', () {
      test('persists an account', () async {
        // Given
        final account = _account(id: 'create-account', name: 'Checking');

        // When
        final result = await repository.create(account);

        // Then
        expect(result.isSuccess, isTrue);

        final stored = (await repository.getById(account.id)).valueOrNull;
        expect(stored?.id, account.id);
        expect(stored?.name, 'Checking');
        expect(stored?.custodianId, account.custodianId);
      });

      test('returns concrete failures for invalid create states', () async {
        // Given
        final active = _account(id: 'create-active');
        await repository.create(active);

        final duplicate = _account(id: active.id.value, name: 'Duplicate');

        final archived = _account(
          id: 'create-archived',
          archivedAt: archivedAt,
        );

        final deleted = _account(id: 'create-deleted', deletedAt: deletedAt);

        // When
        final duplicateResult = await repository.create(duplicate);
        final archivedResult = await repository.create(archived);
        final deletedResult = await repository.create(deleted);

        // Then
        expect(
          duplicateResult.failureOrNull,
          isA<AccountAlreadyExistsFailure>(),
        );
        expect(
          archivedResult.failureOrNull,
          isA<AccountAlreadyArchivedFailure>(),
        );
        expect(
          deletedResult.failureOrNull,
          isA<AccountAlreadyDeletedFailure>(),
        );
      });
    });

    group('queries', () {
      test('getAll returns all accounts through immutable list', () async {
        // Given
        final first = _account(id: 'all-first');
        final second = _account(id: 'all-second');

        await repository.create(second);
        await repository.create(first);

        // When
        final accounts = (await repository.getAll()).valueOrNull!;

        // Then
        expect(
          accounts.map((account) => account.id),
          unorderedEquals([first.id, second.id]),
        );
        expect(() => accounts.clear(), throwsUnsupportedError);
      });

      test('returns successful null for missing account', () async {
        // When
        final result = await repository.getById(
          AccountId.fromString('missing'),
        );

        // Then
        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull, isNull);
      });

      test('filters by custodian ID', () async {
        // Given
        final first = _account(
          id: 'custodian-first',
          custodianId: 'custodian-target',
        );
        final unrelated = _account(
          id: 'custodian-other',
          custodianId: 'custodian-other',
        );
        final second = _account(
          id: 'custodian-second',
          custodianId: 'custodian-target',
        );

        await repository.create(first);
        await repository.create(unrelated);
        await repository.create(second);

        // When
        final accounts = (await repository.getByCustodianId(
          CustodianId.fromString('custodian-target'),
        )).valueOrNull!;

        // Then
        expect(
          accounts.map((account) => account.id),
          unorderedEquals([first.id, second.id]),
        );
        expect(() => accounts.clear(), throwsUnsupportedError);
      });

      test('searches account names case-insensitively', () async {
        // Given
        final first = _account(id: 'search-first', name: 'Holiday Savings');
        final second = _account(id: 'search-second', name: 'Emergency savings');
        final unrelated = _account(id: 'search-other', name: 'Checking');

        await repository.create(first);
        await repository.create(unrelated);
        await repository.create(second);

        // When
        final accounts = (await repository.search('SAVINGS')).valueOrNull!;

        // Then
        expect(
          accounts.map((account) => account.id),
          unorderedEquals([first.id, second.id]),
        );
        expect(() => accounts.clear(), throwsUnsupportedError);
      });

      test('separates active and archived accounts', () async {
        // Given
        final active = _account(id: 'active');
        final archived = _account(id: 'archived');

        await repository.create(active);
        await repository.create(archived);
        await repository.archive(archived.id, archivedAt);

        // When
        final activeResults = (await repository.getActive()).valueOrNull!;
        final archivedResults = (await repository.getArchived()).valueOrNull!;

        // Then
        expect(activeResults.map((account) => account.id), [active.id]);
        expect(archivedResults.map((account) => account.id), [archived.id]);

        expect(() => activeResults.clear(), throwsUnsupportedError);
        expect(() => archivedResults.clear(), throwsUnsupportedError);
      });
    });

    group('update', () {
      test('replaces stored snapshot', () async {
        // Given
        final original = _account(
          id: 'update',
          name: 'Original',
          entityVersion: 4,
        );

        final replacement = _account(
          id: original.id.value,
          name: 'Updated',
          modifiedAt: modifiedAt,
          entityVersion: original.entityVersion,
        );

        await repository.create(original);

        // When
        final result = await repository.update(replacement);

        // Then
        expect(result.isSuccess, isTrue);

        final stored = (await repository.getById(original.id)).valueOrNull!;

        expect(stored.name, 'Updated');
        expect(stored.entityVersion, 4);
      });

      test('returns typed failures for missing and deleted accounts', () async {
        // Given
        final original = _account(id: 'update-original');
        await repository.create(original);

        // When
        final missingResult = await repository.update(
          _account(id: 'update-missing'),
        );

        final deletedResult = await repository.update(
          _account(id: original.id.value, deletedAt: deletedAt),
        );

        // Then
        expect(missingResult.failureOrNull, isA<AccountNotFoundFailure>());
        expect(
          deletedResult.failureOrNull,
          isA<AccountAlreadyDeletedFailure>(),
        );
      });
    });

    group('archive and unarchive', () {
      test('persists archive state and modification timestamps', () async {
        // Given
        final account = _account(id: 'archive');
        await repository.create(account);

        // When
        final archived = await repository.archive(account.id, archivedAt);
        final unarchived = await repository.unarchive(account.id, modifiedAt);

        // Then
        expect(archived.valueOrNull?.archivedAt, archivedAt);
        expect(archived.valueOrNull?.modifiedAt, archivedAt);

        expect(unarchived.valueOrNull?.archivedAt, isNull);
        expect(unarchived.valueOrNull?.modifiedAt, modifiedAt);
      });

      test('returns concrete failures for invalid transitions', () async {
        // Given
        final account = _account(id: 'transition');
        await repository.create(account);

        // When
        final missingArchive = await repository.archive(
          AccountId.fromString('archive-missing'),
          archivedAt,
        );

        await repository.archive(account.id, archivedAt);

        final duplicateArchive = await repository.archive(
          account.id,
          archivedAt,
        );

        await repository.unarchive(account.id, modifiedAt);

        final activeUnarchive = await repository.unarchive(
          account.id,
          modifiedAt,
        );

        // Then
        expect(missingArchive.failureOrNull, isA<AccountNotFoundFailure>());
        expect(
          duplicateArchive.failureOrNull,
          isA<AccountAlreadyArchivedFailure>(),
        );
        expect(activeUnarchive.failureOrNull, isA<AccountNotArchivedFailure>());
      });
    });

    group('delete and restore', () {
      test(
        'physically deletes and restores while preserving archive state',
        () async {
          // Given
          final account = _account(id: 'delete-restore');

          await repository.create(account);
          await repository.archive(account.id, archivedAt);

          // When
          final deleteResult = await repository.delete(account.id);

          // Then
          final deleted = deleteResult.valueOrNull!;

          expect(deleted.deletedAt, isNotNull);
          expect(deleted.archivedAt, archivedAt);
          expect((await repository.getById(account.id)).valueOrNull, isNull);

          // When
          final restoreResult = await repository.restore(deleted);

          // Then
          expect(restoreResult.isSuccess, isTrue);

          final restored = (await repository.getById(account.id)).valueOrNull!;

          expect(restored.deletedAt, isNull);
          expect(restored.archivedAt, archivedAt);
        },
      );

      test(
        'rejects missing delete, active restore and duplicate restore',
        () async {
          // Given
          final active = _account(id: 'restore-active');
          await repository.create(active);

          final deletedDuplicate = _account(
            id: active.id.value,
            deletedAt: deletedAt,
          );

          // When
          final missingDelete = await repository.delete(
            AccountId.fromString('delete-missing'),
          );
          final activeRestore = await repository.restore(active);
          final duplicateRestore = await repository.restore(deletedDuplicate);

          // Then
          expect(missingDelete.failureOrNull, isA<AccountNotFoundFailure>());
          expect(
            activeRestore.failureOrNull,
            isA<AccountAlreadyActiveFailure>(),
          );
          expect(
            duplicateRestore.failureOrNull,
            isA<AccountAlreadyExistsFailure>(),
          );
        },
      );
    });

    test('translates malformed persisted account to typed failure', () async {
      // Given
      const id = 'corrupt-account';

      await SembastStores.accounts
          .record(id)
          .put(database, <String, Object?>{});

      // When
      final result = await repository.getById(AccountId.fromString(id));

      // Then
      expect(result.failureOrNull, isA<AccountPersistenceFailure>());
    });
  });
}

Account _account({
  required String id,
  String name = 'Account',
  String custodianId = 'custodian-bank',
  DateTime? archivedAt,
  DateTime? deletedAt,
  DateTime? modifiedAt,
  int entityVersion = 1,
}) {
  final createdAt = DateTime.utc(2026, 1, 1);

  return Account(
    id: AccountId.fromString(id),
    name: name,
    custodianId: CustodianId.fromString(custodianId),
    denominationAssetId: AssetId.fromString('asset-chf'),
    kind: AccountKind.checking,
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
