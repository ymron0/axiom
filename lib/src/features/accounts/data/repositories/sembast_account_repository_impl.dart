import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/custodian_id.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record.dart';
import 'package:axiom/src/core/persistence/persistence_operation_guard.dart';
import 'package:axiom/src/core/persistence/sembast_stores.dart';
import 'package:axiom/src/core/ports/clock/clock_factory.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/accounts/data/models/account_persistence_model.dart';
import 'package:axiom/src/features/accounts/domain/entities/account.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_already_active_failure.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_already_archived_failure.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_already_deleted_failure.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_already_exists_failure.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_failure.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_not_archived_failure.dart';
import 'package:axiom/src/features/accounts/domain/failures/account_not_found_failure.dart';
import 'package:axiom/src/features/accounts/data/failures/account_persistence_failure.dart';
import 'package:axiom/src/features/accounts/domain/repositories/account_repository.dart';
import 'package:sembast/sembast.dart';

/// Persists accounts in the Sembast accounts store.
///
/// The repository implements the storage-independent [AccountRepository]
/// contract while keeping all Sembast details inside the data layer.
///
/// ## Identity
///
/// [Account.id] is used as the Sembast record key.
///
/// Account identity is therefore never duplicated inside the record value.
///
/// ## Deleted accounts
///
/// Account deletion is physical.
///
/// Deleted snapshots are returned to the caller but are not retained in the
/// accounts store. Restoration requires the caller-retained deleted snapshot.
///
/// ## Archived accounts
///
/// Archival differs from deletion. Archived accounts remain persisted and can
/// be returned by [getAll], [getArchived], [getByCustodianId], [getById], and
/// [search].
///
/// ## Transactions
///
/// Write operations that depend on existing storage state use Sembast
/// transactions so validation and mutation occur atomically.
///
/// ## Failure translation
///
/// Expected persistence exceptions are translated to
/// [AccountPersistenceFailure] through [guardPersistenceOperation].
///
/// Domain failures such as [AccountNotFoundFailure] and
/// [AccountAlreadyExistsFailure] remain explicit typed results.
///
/// Programmer errors and violated internal assumptions deliberately propagate.
final class SembastAccountRepositoryImpl implements AccountRepository {
  static final StoreRef<String, PersistenceRecord> _store =
      SembastStores.accounts;

  final Database _database;

  /// Creates an account repository backed by an already-open and validated
  /// [database].
  ///
  /// Database lifecycle ownership remains outside this repository. This
  /// repository never opens or closes the supplied database.
  // ignore: prefer_initializing_formals
  SembastAccountRepositoryImpl({required Database database})
    : _database = database; // ignore: prefer_initializing_formals

  @override
  Future<Result<Account, AccountFailure>> archive(
    AccountId id,
    DateTime archivedAt,
  ) => guardPersistenceOperation<Account, AccountFailure>(
    operation: () => _database.transaction((transaction) async {
      final record = _store.record(id.value);
      final persistedRecord = await record.get(transaction);

      if (persistedRecord == null) {
        return AccountNotFoundFailure(
          message: 'Account ID was not found: ${id.value}',
        );
      }

      final account = _accountFromRecord(
        recordKey: id.value,
        record: persistedRecord,
      );

      if (account.isArchived) {
        return AccountAlreadyArchivedFailure(
          message: 'Account is already archived: ${id.value}',
        );
      }

      final archivedAccount = _withArchivedAt(
        account,
        archivedAt: archivedAt,
        modifiedAt: archivedAt,
      );

      final model = AccountPersistenceModel.fromEntity(archivedAccount);

      await record.put(transaction, model.toRecord());

      return Success(archivedAccount);
    }),
    persistenceFailure: _persistenceFailure,
    failureMessage: 'Unable to archive the account.',
  );

  @override
  Future<Result<void, AccountFailure>> create(Account account) {
    if (account.isDeleted) {
      return Future.value(
        AccountAlreadyDeletedFailure(
          message: 'Deleted account cannot be created: ${account.id.value}',
        ),
      );
    }

    if (account.isArchived) {
      return Future.value(
        AccountAlreadyArchivedFailure(
          message: 'Archived account cannot be created: ${account.id.value}',
        ),
      );
    }

    return guardPersistenceOperation<void, AccountFailure>(
      operation: () => _database.transaction((transaction) async {
        final record = _store.record(account.id.value);
        final existingRecord = await record.get(transaction);

        if (existingRecord != null) {
          return AccountAlreadyExistsFailure(
            message: 'Account ID already exists: ${account.id.value}',
          );
        }

        final model = AccountPersistenceModel.fromEntity(account);

        await record.put(transaction, model.toRecord());

        return const Success(null);
      }),
      persistenceFailure: _persistenceFailure,
      failureMessage: 'Unable to create the account.',
    );
  }

  @override
  Future<Result<Account, AccountFailure>> delete(AccountId id) =>
      guardPersistenceOperation<Account, AccountFailure>(
        operation: () => _database.transaction((transaction) async {
          final record = _store.record(id.value);
          final persistedRecord = await record.get(transaction);

          if (persistedRecord == null) {
            return AccountNotFoundFailure(
              message: 'Account ID was not found: ${id.value}',
            );
          }

          final account = _accountFromRecord(
            recordKey: id.value,
            record: persistedRecord,
          );

          final deletedAccount = _withDeletedAt(account, createClock().now);

          await record.delete(transaction);

          return Success(deletedAccount);
        }),
        persistenceFailure: _persistenceFailure,
        failureMessage: 'Unable to delete the account.',
      );

  @override
  Future<Result<List<Account>, AccountFailure>> getActive() =>
      guardPersistenceOperation<List<Account>, AccountFailure>(
        operation: () async {
          final accounts = await _loadAllAccounts(_database);

          final activeAccounts = accounts
              .where((account) => !account.isArchived)
              .toList(growable: false);

          return Success(List<Account>.unmodifiable(activeAccounts));
        },
        persistenceFailure: _persistenceFailure,
        failureMessage: 'Unable to load the active accounts.',
      );

  @override
  Future<Result<List<Account>, AccountFailure>> getAll() =>
      guardPersistenceOperation<List<Account>, AccountFailure>(
        operation: () async {
          final accounts = await _loadAllAccounts(_database);

          return Success(List<Account>.unmodifiable(accounts));
        },
        persistenceFailure: _persistenceFailure,
        failureMessage: 'Unable to load the accounts.',
      );

  @override
  Future<Result<List<Account>, AccountFailure>> getArchived() =>
      guardPersistenceOperation<List<Account>, AccountFailure>(
        operation: () async {
          final accounts = await _loadAllAccounts(_database);

          final archivedAccounts = accounts
              .where((account) => account.isArchived)
              .toList(growable: false);

          return Success(List<Account>.unmodifiable(archivedAccounts));
        },
        persistenceFailure: _persistenceFailure,
        failureMessage: 'Unable to load the archived accounts.',
      );

  @override
  Future<Result<List<Account>, AccountFailure>> getByCustodianId(
    CustodianId custodianId,
  ) => guardPersistenceOperation<List<Account>, AccountFailure>(
    operation: () async {
      final snapshots = await _store.find(
        _database,
        finder: Finder(
          filter: Filter.equals(
            AccountPersistenceModel.custodianIdField,
            custodianId.value,
          ),
        ),
      );

      final accounts = snapshots
          .map(_accountFromSnapshot)
          .toList(growable: false);

      return Success(List<Account>.unmodifiable(accounts));
    },
    persistenceFailure: _persistenceFailure,
    failureMessage: 'Unable to load accounts by custodian ID.',
  );

  @override
  Future<Result<Account?, AccountFailure>> getById(AccountId id) =>
      guardPersistenceOperation<Account?, AccountFailure>(
        operation: () async {
          final record = await _store.record(id.value).get(_database);

          if (record == null) {
            return const Success(null);
          }

          return Success(
            _accountFromRecord(recordKey: id.value, record: record),
          );
        },
        persistenceFailure: _persistenceFailure,
        failureMessage: 'Unable to load the account by ID.',
      );

  @override
  Future<Result<void, AccountFailure>> restore(Account account) {
    if (!account.isDeleted) {
      return Future.value(
        AccountAlreadyActiveFailure(
          message: 'Account is already active: ${account.id.value}',
        ),
      );
    }

    return guardPersistenceOperation<void, AccountFailure>(
      operation: () => _database.transaction((transaction) async {
        final record = _store.record(account.id.value);
        final existingRecord = await record.get(transaction);

        if (existingRecord != null) {
          return AccountAlreadyExistsFailure(
            message: 'Account ID already exists: ${account.id.value}',
          );
        }

        final restoredAccount = _withDeletedAt(account, null);

        final model = AccountPersistenceModel.fromEntity(restoredAccount);

        await record.put(transaction, model.toRecord());

        return const Success(null);
      }),
      persistenceFailure: _persistenceFailure,
      failureMessage: 'Unable to restore the account.',
    );
  }

  @override
  Future<Result<List<Account>, AccountFailure>> search(String query) =>
      guardPersistenceOperation<List<Account>, AccountFailure>(
        operation: () async {
          final accounts = await _loadAllAccounts(_database);
          final normalizedQuery = query.toLowerCase();

          final matches = accounts
              .where(
                (account) =>
                    account.name.toLowerCase().contains(normalizedQuery),
              )
              .toList(growable: false);

          return Success(List<Account>.unmodifiable(matches));
        },
        persistenceFailure: _persistenceFailure,
        failureMessage: 'Unable to search accounts.',
      );

  @override
  Future<Result<Account, AccountFailure>> unarchive(
    AccountId id,
    DateTime modifiedAt,
  ) => guardPersistenceOperation<Account, AccountFailure>(
    operation: () => _database.transaction((transaction) async {
      final record = _store.record(id.value);
      final persistedRecord = await record.get(transaction);

      if (persistedRecord == null) {
        return AccountNotFoundFailure(
          message: 'Account ID was not found: ${id.value}',
        );
      }

      final account = _accountFromRecord(
        recordKey: id.value,
        record: persistedRecord,
      );

      if (!account.isArchived) {
        return AccountNotArchivedFailure(
          message: 'Account is not archived: ${id.value}',
        );
      }

      final unarchivedAccount = _withArchivedAt(
        account,
        archivedAt: null,
        modifiedAt: modifiedAt,
      );

      final model = AccountPersistenceModel.fromEntity(unarchivedAccount);

      await record.put(transaction, model.toRecord());

      return Success(unarchivedAccount);
    }),
    persistenceFailure: _persistenceFailure,
    failureMessage: 'Unable to unarchive the account.',
  );

  @override
  Future<Result<void, AccountFailure>> update(Account account) {
    if (account.isDeleted) {
      return Future.value(
        AccountAlreadyDeletedFailure(
          message: 'Deleted account cannot be updated: ${account.id.value}',
        ),
      );
    }

    return guardPersistenceOperation<void, AccountFailure>(
      operation: () => _database.transaction((transaction) async {
        final record = _store.record(account.id.value);
        final existingRecord = await record.get(transaction);

        if (existingRecord == null) {
          return AccountNotFoundFailure(
            message: 'Account ID was not found: ${account.id.value}',
          );
        }

        final model = AccountPersistenceModel.fromEntity(account);

        await record.put(transaction, model.toRecord());

        return const Success(null);
      }),
      persistenceFailure: _persistenceFailure,
      failureMessage: 'Unable to update the account.',
    );
  }

  /// Reconstructs an account from its persisted record key and value.
  static Account _accountFromRecord({
    required String recordKey,
    required PersistenceRecord record,
  }) => AccountPersistenceModel.fromRecord(
    recordKey: recordKey,
    record: record,
  ).toEntity();

  /// Reconstructs an account from a Sembast record snapshot.
  static Account _accountFromSnapshot(
    RecordSnapshot<String, PersistenceRecord> snapshot,
  ) => _accountFromRecord(recordKey: snapshot.key, record: snapshot.value);

  /// Loads every persisted account and reconstructs the corresponding domain
  /// entities.
  ///
  /// Any malformed persisted record causes [PersistenceRecordException] inside
  /// the persistence model, which the public operation guard translates into
  /// [AccountPersistenceFailure].
  static Future<List<Account>> _loadAllAccounts(
    DatabaseClient databaseClient,
  ) async {
    final snapshots = await _store.find(databaseClient);

    return snapshots.map(_accountFromSnapshot).toList(growable: false);
  }

  /// Creates the feature-specific failure returned when persistence
  /// infrastructure cannot complete an operation.
  static AccountPersistenceFailure _persistenceFailure(String message) =>
      AccountPersistenceFailure(message: message);

  /// Creates a new account snapshot differing in archive state and modification
  /// timestamp.
  static Account _withArchivedAt(
    Account account, {
    required DateTime? archivedAt,
    required DateTime modifiedAt,
  }) => Account(
    id: account.id,
    name: account.name,
    custodianId: account.custodianId,
    denominationAssetId: account.denominationAssetId,
    kind: account.kind,
    reference: account.reference,
    logo: account.logo,
    icon: account.icon,
    color: account.color,
    sortOrder: account.sortOrder,
    archivedAt: archivedAt,
    deletedAt: account.deletedAt,
    createdAt: account.createdAt,
    modifiedAt: modifiedAt,
    entityVersion: account.entityVersion,
  );

  /// Creates a new account snapshot differing only in deletion state.
  ///
  /// Account deletion does not alter [Account.modifiedAt]; the returned
  /// snapshot carries the deletion timestamp separately.
  static Account _withDeletedAt(Account account, DateTime? deletedAt) =>
      Account(
        id: account.id,
        name: account.name,
        custodianId: account.custodianId,
        denominationAssetId: account.denominationAssetId,
        kind: account.kind,
        reference: account.reference,
        logo: account.logo,
        icon: account.icon,
        color: account.color,
        sortOrder: account.sortOrder,
        archivedAt: account.archivedAt,
        deletedAt: deletedAt,
        createdAt: account.createdAt,
        modifiedAt: account.modifiedAt,
        entityVersion: account.entityVersion,
      );
}
