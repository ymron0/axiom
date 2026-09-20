import 'package:axiom/src/core/identity/ids/merchant_id.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_exception.dart';
import 'package:axiom/src/core/persistence/persistence_operation_guard.dart';
import 'package:axiom/src/core/persistence/sembast_stores.dart';
import 'package:axiom/src/core/ports/clock/clock_factory.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/merchants/data/models/merchant_persistence_model.dart';
import 'package:axiom/src/features/merchants/domain/entities/merchant.dart';
import 'package:axiom/src/features/merchants/domain/failures/merchant_already_active_failure.dart';
import 'package:axiom/src/features/merchants/domain/failures/merchant_already_archived_failure.dart';
import 'package:axiom/src/features/merchants/domain/failures/merchant_already_deleted_failure.dart';
import 'package:axiom/src/features/merchants/domain/failures/merchant_already_exists_failure.dart';
import 'package:axiom/src/features/merchants/domain/failures/merchant_failure.dart';
import 'package:axiom/src/features/merchants/domain/failures/merchant_not_archived_failure.dart';
import 'package:axiom/src/features/merchants/domain/failures/merchant_not_found_failure.dart';
import 'package:axiom/src/features/merchants/data/failures/merchant_persistence_failure.dart';
import 'package:axiom/src/features/merchants/domain/repositories/merchant_repository.dart';
import 'package:sembast/sembast.dart';

/// Persists merchants in the application's Sembast database.
///
/// ## Storage
///
/// Each merchant is stored in [SembastStores.merchants].
///
/// [MerchantId.value] is used directly as the Sembast record key. The
/// identifier is therefore not duplicated inside the persisted record.
///
/// ## Deletion semantics
///
/// Merchant deletion is physical. A deleted merchant is removed from the
/// store and returned to the caller as a snapshot whose [Merchant.deletedAt]
/// contains the deletion timestamp.
///
/// Consequently, a merchant record found in the store with a non-null
/// `deletedAt` value is considered corrupt persisted data.
///
/// ## Failure translation
///
/// Expected domain conditions such as duplicate identities, missing merchants,
/// invalid archive state, and invalid restore state use their existing
/// merchant-domain failures.
///
/// Persistence infrastructure errors are translated into
/// [MerchantPersistenceFailure].
///
/// Programmer errors and caller-supplied domain invariant violations are not
/// swallowed by this repository.
final class SembastMerchantRepositoryImpl implements MerchantRepository {
  static final StoreRef<String, PersistenceRecord> _store =
      SembastStores.merchants;

  final Database _database;

  /// Creates a merchant repository backed by an already-open [database].
  ///
  /// Database lifecycle ownership remains outside feature repositories.
  SembastMerchantRepositoryImpl({required Database database})
    : _database = // ignore: prefer_initializing_formals
          database;

  @override
  Future<Result<void, MerchantFailure>> create(Merchant merchant) async {
    if (merchant.isDeleted) {
      return MerchantAlreadyDeletedFailure(
        message: 'Deleted merchant cannot be created: ${merchant.id.value}',
      );
    }

    if (merchant.isArchived) {
      return MerchantAlreadyArchivedFailure(
        message: 'Archived merchant cannot be created: ${merchant.id.value}',
      );
    }

    return guardPersistenceOperation<void, MerchantFailure>(
      operation: () {
        return _database.transaction<Result<void, MerchantFailure>>((
          transaction,
        ) async {
          final record = _store.record(merchant.id.value);
          final existingRecord = await record.get(transaction);

          if (existingRecord != null) {
            return MerchantAlreadyExistsFailure(
              message: 'Merchant ID already exists: ${merchant.id.value}',
            );
          }

          final persistenceModel = MerchantPersistenceModel.fromEntity(
            merchant,
          );

          await record.put(transaction, persistenceModel.toRecord());

          return const Success(null);
        });
      },
      persistenceFailure: _persistenceFailure,
      failureMessage: 'Failed to create merchant.',
    );
  }

  @override
  Future<Result<List<Merchant>, MerchantFailure>> getAll() {
    return _readMatching(
      matches: (_) => true,
      failureMessage: 'Failed to read merchants.',
    );
  }

  @override
  Future<Result<List<Merchant>, MerchantFailure>> getActive() {
    return _readMatching(
      matches: (merchant) => !merchant.isArchived,
      failureMessage: 'Failed to read active merchants.',
    );
  }

  @override
  Future<Result<List<Merchant>, MerchantFailure>> getArchived() {
    return _readMatching(
      matches: (merchant) => merchant.isArchived,
      failureMessage: 'Failed to read archived merchants.',
    );
  }

  @override
  Future<Result<Merchant?, MerchantFailure>> getById(MerchantId id) {
    return guardPersistenceOperation<Merchant?, MerchantFailure>(
      operation: () async {
        final record = await _store.record(id.value).get(_database);

        if (record == null) {
          return const Success(null);
        }

        final merchant = _merchantFromRecord(
          recordKey: id.value,
          record: record,
        );

        return Success(merchant);
      },
      persistenceFailure: _persistenceFailure,
      failureMessage: 'Failed to read merchant.',
    );
  }

  @override
  Future<Result<List<Merchant>, MerchantFailure>> search(String query) {
    final normalizedQuery = query.toLowerCase();

    return _readMatching(
      matches: (merchant) {
        return merchant.name.toLowerCase().contains(normalizedQuery);
      },
      failureMessage: 'Failed to search merchants.',
    );
  }

  @override
  Future<Result<void, MerchantFailure>> update(Merchant merchant) async {
    if (merchant.isDeleted) {
      return MerchantAlreadyDeletedFailure(
        message: 'Deleted merchant cannot be updated: ${merchant.id.value}',
      );
    }

    return guardPersistenceOperation<void, MerchantFailure>(
      operation: () {
        return _database.transaction<Result<void, MerchantFailure>>((
          transaction,
        ) async {
          final record = _store.record(merchant.id.value);
          final existingRecord = await record.get(transaction);

          if (existingRecord == null) {
            return MerchantNotFoundFailure(
              message: 'Merchant ID was not found: ${merchant.id.value}',
            );
          }

          final persistenceModel = MerchantPersistenceModel.fromEntity(
            merchant,
          );

          await record.put(transaction, persistenceModel.toRecord());

          return const Success(null);
        });
      },
      persistenceFailure: _persistenceFailure,
      failureMessage: 'Failed to update merchant.',
    );
  }

  @override
  Future<Result<Merchant, MerchantFailure>> archive(
    MerchantId id,
    DateTime archivedAt,
  ) {
    return guardPersistenceOperation<Merchant, MerchantFailure>(
      operation: () {
        return _database.transaction<Result<Merchant, MerchantFailure>>((
          transaction,
        ) async {
          final record = _store.record(id.value);
          final persistedRecord = await record.get(transaction);

          if (persistedRecord == null) {
            return _notFound(id);
          }

          final merchant = _merchantFromRecord(
            recordKey: id.value,
            record: persistedRecord,
          );

          if (merchant.isArchived) {
            return MerchantAlreadyArchivedFailure(
              message: 'Merchant is already archived: ${id.value}',
            );
          }

          final archivedMerchant = _withArchivedAt(
            merchant,
            archivedAt: archivedAt,
            modifiedAt: archivedAt,
          );

          await record.put(
            transaction,
            MerchantPersistenceModel.fromEntity(archivedMerchant).toRecord(),
          );

          return Success(archivedMerchant);
        });
      },
      persistenceFailure: _persistenceFailure,
      failureMessage: 'Failed to archive merchant.',
    );
  }

  @override
  Future<Result<Merchant, MerchantFailure>> unarchive(
    MerchantId id,
    DateTime modifiedAt,
  ) {
    return guardPersistenceOperation<Merchant, MerchantFailure>(
      operation: () {
        return _database.transaction<Result<Merchant, MerchantFailure>>((
          transaction,
        ) async {
          final record = _store.record(id.value);
          final persistedRecord = await record.get(transaction);

          if (persistedRecord == null) {
            return _notFound(id);
          }

          final merchant = _merchantFromRecord(
            recordKey: id.value,
            record: persistedRecord,
          );

          if (!merchant.isArchived) {
            return MerchantNotArchivedFailure(
              message: 'Merchant is not archived: ${id.value}',
            );
          }

          final unarchivedMerchant = _withArchivedAt(
            merchant,
            archivedAt: null,
            modifiedAt: modifiedAt,
          );

          await record.put(
            transaction,
            MerchantPersistenceModel.fromEntity(unarchivedMerchant).toRecord(),
          );

          return Success(unarchivedMerchant);
        });
      },
      persistenceFailure: _persistenceFailure,
      failureMessage: 'Failed to unarchive merchant.',
    );
  }

  @override
  Future<Result<Merchant, MerchantFailure>> delete(MerchantId id) {
    return guardPersistenceOperation<Merchant, MerchantFailure>(
      operation: () {
        return _database.transaction<Result<Merchant, MerchantFailure>>((
          transaction,
        ) async {
          final record = _store.record(id.value);
          final persistedRecord = await record.get(transaction);

          if (persistedRecord == null) {
            return _notFound(id);
          }

          final merchant = _merchantFromRecord(
            recordKey: id.value,
            record: persistedRecord,
          );

          final deletedMerchant = _withDeletedAt(
            merchant,
            createClock().nowUtc,
          );

          await record.delete(transaction);

          return Success(deletedMerchant);
        });
      },
      persistenceFailure: _persistenceFailure,
      failureMessage: 'Failed to delete merchant.',
    );
  }

  @override
  Future<Result<void, MerchantFailure>> restore(Merchant merchant) async {
    if (!merchant.isDeleted) {
      return MerchantAlreadyActiveFailure(
        message: 'Merchant is already active: ${merchant.id.value}',
      );
    }

    final restoredMerchant = _withDeletedAt(merchant, null);

    return guardPersistenceOperation<void, MerchantFailure>(
      operation: () {
        return _database.transaction<Result<void, MerchantFailure>>((
          transaction,
        ) async {
          final record = _store.record(merchant.id.value);
          final existingRecord = await record.get(transaction);

          if (existingRecord != null) {
            return MerchantAlreadyExistsFailure(
              message: 'Merchant ID already exists: ${merchant.id.value}',
            );
          }

          await record.put(
            transaction,
            MerchantPersistenceModel.fromEntity(restoredMerchant).toRecord(),
          );

          return const Success(null);
        });
      },
      persistenceFailure: _persistenceFailure,
      failureMessage: 'Failed to restore merchant.',
    );
  }

  /// Reads all persisted merchants satisfying [matches].
  ///
  /// The returned collection is always immutable.
  ///
  /// All persisted records are reconstructed through
  /// [MerchantPersistenceModel], so malformed persistence cannot silently
  /// enter the domain.
  Future<Result<List<Merchant>, MerchantFailure>> _readMatching({
    required bool Function(Merchant merchant) matches,
    required String failureMessage,
  }) {
    return guardPersistenceOperation<List<Merchant>, MerchantFailure>(
      operation: () async {
        final snapshots = await _store.find(_database);
        final merchants = <Merchant>[];

        for (final snapshot in snapshots) {
          final merchant = _merchantFromSnapshot(snapshot);

          if (matches(merchant)) {
            merchants.add(merchant);
          }
        }

        return Success(List<Merchant>.unmodifiable(merchants));
      },
      persistenceFailure: _persistenceFailure,
      failureMessage: failureMessage,
    );
  }

  /// Converts a Sembast record snapshot into a valid merchant entity.
  static Merchant _merchantFromSnapshot(
    RecordSnapshot<String, PersistenceRecord> snapshot,
  ) {
    return _merchantFromRecord(recordKey: snapshot.key, record: snapshot.value);
  }

  /// Converts persisted record data into a valid merchant entity.
  ///
  /// Deleted merchants are forbidden in the merchant store because deletion
  /// is physical according to [MerchantRepository].
  static Merchant _merchantFromRecord({
    required String recordKey,
    required PersistenceRecord record,
  }) {
    final merchant = MerchantPersistenceModel.fromRecord(
      recordKey: recordKey,
      record: record,
    ).toEntity();

    if (merchant.isDeleted) {
      throw const PersistenceRecordException(
        field: MerchantPersistenceModel.deletedAtField,
        reason: 'Deleted merchants must not be persisted.',
      );
    }

    return merchant;
  }

  /// Creates a typed missing-merchant result.
  static MerchantNotFoundFailure _notFound(MerchantId id) {
    return MerchantNotFoundFailure(
      message: 'Merchant ID was not found: ${id.value}',
    );
  }

  /// Creates a merchant snapshot with the requested archive state.
  ///
  /// Domain reconstruction deliberately re-applies all merchant invariants.
  static Merchant _withArchivedAt(
    Merchant merchant, {
    required DateTime? archivedAt,
    required DateTime modifiedAt,
  }) {
    return Merchant(
      id: merchant.id,
      name: merchant.name,
      createdAt: merchant.createdAt,
      modifiedAt: modifiedAt,
      archivedAt: archivedAt,
      deletedAt: merchant.deletedAt,
      entityVersion: merchant.entityVersion,
    );
  }

  /// Creates a merchant snapshot with the requested deletion state.
  static Merchant _withDeletedAt(Merchant merchant, DateTime? deletedAt) {
    return Merchant(
      id: merchant.id,
      name: merchant.name,
      createdAt: merchant.createdAt,
      modifiedAt: merchant.modifiedAt,
      archivedAt: merchant.archivedAt,
      deletedAt: deletedAt,
      entityVersion: merchant.entityVersion,
    );
  }

  /// Creates the feature-specific failure used for infrastructure errors.
  static MerchantPersistenceFailure _persistenceFailure(String message) {
    return MerchantPersistenceFailure(message: message);
  }
}
