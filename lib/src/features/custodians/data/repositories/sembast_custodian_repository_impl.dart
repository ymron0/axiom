import 'package:axiom/src/core/identity/ids/custodian_id.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record.dart';
import 'package:axiom/src/core/persistence/persistence_operation_guard.dart';
import 'package:axiom/src/core/persistence/sembast_stores.dart';
import 'package:axiom/src/core/ports/clock/clock_factory.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/custodians/domain/entities/custodian.dart';
import 'package:axiom/src/features/custodians/domain/failures/custodian_already_active_failure.dart';
import 'package:axiom/src/features/custodians/domain/failures/custodian_already_archived_failure.dart';
import 'package:axiom/src/features/custodians/domain/failures/custodian_already_deleted_failure.dart';
import 'package:axiom/src/features/custodians/domain/failures/custodian_already_exists_failure.dart';
import 'package:axiom/src/features/custodians/domain/failures/custodian_failure.dart';
import 'package:axiom/src/features/custodians/domain/failures/custodian_not_archived_failure.dart';
import 'package:axiom/src/features/custodians/domain/failures/custodian_not_found_failure.dart';
import 'package:axiom/src/features/custodians/domain/failures/custodian_repository_failure.dart';
import 'package:axiom/src/features/custodians/domain/repositories/custodian_repository.dart';
import 'package:axiom/src/features/custodians/data/models/custodian_persistence_model.dart';
import 'package:sembast/sembast.dart';

/// Persists custodians in the Sembast custodians store.
///
/// The repository implements the storage-independent [CustodianRepository]
/// contract while keeping all Sembast details inside the data layer.
///
/// ## Identity
///
/// [Custodian.id] is used as the Sembast record key.
///
/// Custodian identity is therefore never duplicated inside the record value.
///
/// ## Deleted custodians
///
/// Custodian deletion is physical.
///
/// Deleted snapshots are returned to the caller but are not retained in the
/// custodians store. Restoration requires the caller-retained deleted snapshot.
///
/// Whether a custodian may be deleted because of references from accounts is an
/// application-level concern and is deliberately not enforced here.
///
/// ## Archived custodians
///
/// Archival differs from deletion. Archived custodians remain persisted and can
/// be returned by [getAll], [getArchived], [getById], and [search].
///
/// ## Transactions
///
/// Write operations that depend on existing storage state use Sembast
/// transactions so validation and mutation occur atomically.
///
/// ## Failure translation
///
/// Expected persistence exceptions are translated to
/// [CustodianRepositoryFailure] through [guardPersistenceOperation].
///
/// Domain failures such as [CustodianNotFoundFailure] and
/// [CustodianAlreadyExistsFailure] remain explicit typed results.
///
/// Programmer errors and violated internal assumptions deliberately propagate.
final class SembastCustodianRepositoryImpl implements CustodianRepository {
  static final StoreRef<String, PersistenceRecord> _store =
      SembastStores.custodians;

  final Database _database;

  /// Creates a custodian repository backed by an already-open and validated
  /// [database].
  ///
  /// Database lifecycle ownership remains outside this repository. This
  /// repository never opens or closes the supplied database.
  // ignore: prefer_initializing_formals
  SembastCustodianRepositoryImpl({required Database database})
    : _database = database; // ignore: prefer_initializing_formals

  @override
  Future<Result<Custodian, CustodianFailure>> archive(
    CustodianId id,
    DateTime archivedAt,
  ) => guardPersistenceOperation<Custodian, CustodianFailure>(
    operation: () => _database.transaction((transaction) async {
      final record = _store.record(id.value);
      final persistedRecord = await record.get(transaction);

      if (persistedRecord == null) {
        return CustodianNotFoundFailure(
          message: 'Custodian ID was not found: ${id.value}',
        );
      }

      final custodian = _custodianFromRecord(
        recordKey: id.value,
        record: persistedRecord,
      );

      if (custodian.isArchived) {
        return CustodianAlreadyArchivedFailure(
          message: 'Custodian is already archived: ${id.value}',
        );
      }

      final archivedCustodian = _withArchivedAt(
        custodian,
        archivedAt: archivedAt,
        modifiedAt: archivedAt,
      );

      final model = CustodianPersistenceModel.fromEntity(archivedCustodian);

      await record.put(transaction, model.toRecord());

      return Success(archivedCustodian);
    }),
    persistenceFailure: _persistenceFailure,
    failureMessage: 'Unable to archive the custodian.',
  );

  @override
  Future<Result<void, CustodianFailure>> create(Custodian custodian) {
    if (custodian.isDeleted) {
      return Future.value(
        CustodianAlreadyDeletedFailure(
          message: 'Deleted custodian cannot be created: ${custodian.id.value}',
        ),
      );
    }

    if (custodian.isArchived) {
      return Future.value(
        CustodianAlreadyArchivedFailure(
          message:
              'Archived custodian cannot be created: ${custodian.id.value}',
        ),
      );
    }

    return guardPersistenceOperation<void, CustodianFailure>(
      operation: () => _database.transaction((transaction) async {
        final record = _store.record(custodian.id.value);
        final existingRecord = await record.get(transaction);

        if (existingRecord != null) {
          return CustodianAlreadyExistsFailure(
            message: 'Custodian ID already exists: ${custodian.id.value}',
          );
        }

        final model = CustodianPersistenceModel.fromEntity(custodian);

        await record.put(transaction, model.toRecord());

        return const Success(null);
      }),
      persistenceFailure: _persistenceFailure,
      failureMessage: 'Unable to create the custodian.',
    );
  }

  @override
  Future<Result<Custodian, CustodianFailure>> delete(CustodianId id) =>
      guardPersistenceOperation<Custodian, CustodianFailure>(
        operation: () => _database.transaction((transaction) async {
          final record = _store.record(id.value);
          final persistedRecord = await record.get(transaction);

          if (persistedRecord == null) {
            return CustodianNotFoundFailure(
              message: 'Custodian ID was not found: ${id.value}',
            );
          }

          final custodian = _custodianFromRecord(
            recordKey: id.value,
            record: persistedRecord,
          );

          final deletedCustodian = _withDeletedAt(custodian, createClock().now);

          await record.delete(transaction);

          return Success(deletedCustodian);
        }),
        persistenceFailure: _persistenceFailure,
        failureMessage: 'Unable to delete the custodian.',
      );

  @override
  Future<Result<List<Custodian>, CustodianFailure>> getActive() =>
      guardPersistenceOperation<List<Custodian>, CustodianFailure>(
        operation: () async {
          final custodians = await _loadAllCustodians(_database);

          final activeCustodians = custodians
              .where((custodian) => !custodian.isArchived)
              .toList(growable: false);

          return Success(List<Custodian>.unmodifiable(activeCustodians));
        },
        persistenceFailure: _persistenceFailure,
        failureMessage: 'Unable to load the active custodians.',
      );

  @override
  Future<Result<List<Custodian>, CustodianFailure>> getAll() =>
      guardPersistenceOperation<List<Custodian>, CustodianFailure>(
        operation: () async {
          final custodians = await _loadAllCustodians(_database);

          return Success(List<Custodian>.unmodifiable(custodians));
        },
        persistenceFailure: _persistenceFailure,
        failureMessage: 'Unable to load the custodians.',
      );

  @override
  Future<Result<List<Custodian>, CustodianFailure>> getArchived() =>
      guardPersistenceOperation<List<Custodian>, CustodianFailure>(
        operation: () async {
          final custodians = await _loadAllCustodians(_database);

          final archivedCustodians = custodians
              .where((custodian) => custodian.isArchived)
              .toList(growable: false);

          return Success(List<Custodian>.unmodifiable(archivedCustodians));
        },
        persistenceFailure: _persistenceFailure,
        failureMessage: 'Unable to load the archived custodians.',
      );

  @override
  Future<Result<Custodian?, CustodianFailure>> getById(CustodianId id) =>
      guardPersistenceOperation<Custodian?, CustodianFailure>(
        operation: () async {
          final record = await _store.record(id.value).get(_database);

          if (record == null) {
            return const Success(null);
          }

          return Success(
            _custodianFromRecord(recordKey: id.value, record: record),
          );
        },
        persistenceFailure: _persistenceFailure,
        failureMessage: 'Unable to load the custodian by ID.',
      );

  @override
  Future<Result<void, CustodianFailure>> restore(Custodian custodian) {
    if (!custodian.isDeleted) {
      return Future.value(
        CustodianAlreadyActiveFailure(
          message: 'Custodian is already active: ${custodian.id.value}',
        ),
      );
    }

    return guardPersistenceOperation<void, CustodianFailure>(
      operation: () => _database.transaction((transaction) async {
        final record = _store.record(custodian.id.value);
        final existingRecord = await record.get(transaction);

        if (existingRecord != null) {
          return CustodianAlreadyExistsFailure(
            message: 'Custodian ID already exists: ${custodian.id.value}',
          );
        }

        final restoredCustodian = _withDeletedAt(custodian, null);

        final model = CustodianPersistenceModel.fromEntity(restoredCustodian);

        await record.put(transaction, model.toRecord());

        return const Success(null);
      }),
      persistenceFailure: _persistenceFailure,
      failureMessage: 'Unable to restore the custodian.',
    );
  }

  @override
  Future<Result<List<Custodian>, CustodianFailure>> search(String query) =>
      guardPersistenceOperation<List<Custodian>, CustodianFailure>(
        operation: () async {
          final custodians = await _loadAllCustodians(_database);
          final normalizedQuery = query.toLowerCase();

          final matches = custodians
              .where(
                (custodian) =>
                    custodian.name.toLowerCase().contains(normalizedQuery),
              )
              .toList(growable: false);

          return Success(List<Custodian>.unmodifiable(matches));
        },
        persistenceFailure: _persistenceFailure,
        failureMessage: 'Unable to search custodians.',
      );

  @override
  Future<Result<Custodian, CustodianFailure>> unarchive(
    CustodianId id,
    DateTime modifiedAt,
  ) => guardPersistenceOperation<Custodian, CustodianFailure>(
    operation: () => _database.transaction((transaction) async {
      final record = _store.record(id.value);
      final persistedRecord = await record.get(transaction);

      if (persistedRecord == null) {
        return CustodianNotFoundFailure(
          message: 'Custodian ID was not found: ${id.value}',
        );
      }

      final custodian = _custodianFromRecord(
        recordKey: id.value,
        record: persistedRecord,
      );

      if (!custodian.isArchived) {
        return CustodianNotArchivedFailure(
          message: 'Custodian is not archived: ${id.value}',
        );
      }

      final unarchivedCustodian = _withArchivedAt(
        custodian,
        archivedAt: null,
        modifiedAt: modifiedAt,
      );

      final model = CustodianPersistenceModel.fromEntity(unarchivedCustodian);

      await record.put(transaction, model.toRecord());

      return Success(unarchivedCustodian);
    }),
    persistenceFailure: _persistenceFailure,
    failureMessage: 'Unable to unarchive the custodian.',
  );

  @override
  Future<Result<void, CustodianFailure>> update(Custodian custodian) {
    if (custodian.isDeleted) {
      return Future.value(
        CustodianAlreadyDeletedFailure(
          message: 'Deleted custodian cannot be updated: ${custodian.id.value}',
        ),
      );
    }

    return guardPersistenceOperation<void, CustodianFailure>(
      operation: () => _database.transaction((transaction) async {
        final record = _store.record(custodian.id.value);
        final existingRecord = await record.get(transaction);

        if (existingRecord == null) {
          return CustodianNotFoundFailure(
            message: 'Custodian ID was not found: ${custodian.id.value}',
          );
        }

        final model = CustodianPersistenceModel.fromEntity(custodian);

        await record.put(transaction, model.toRecord());

        return const Success(null);
      }),
      persistenceFailure: _persistenceFailure,
      failureMessage: 'Unable to update the custodian.',
    );
  }

  /// Reconstructs a custodian from its persisted record key and value.
  static Custodian _custodianFromRecord({
    required String recordKey,
    required PersistenceRecord record,
  }) => CustodianPersistenceModel.fromRecord(
    recordKey: recordKey,
    record: record,
  ).toEntity();

  /// Reconstructs a custodian from a Sembast record snapshot.
  static Custodian _custodianFromSnapshot(
    RecordSnapshot<String, PersistenceRecord> snapshot,
  ) => _custodianFromRecord(recordKey: snapshot.key, record: snapshot.value);

  /// Loads every persisted custodian and reconstructs the corresponding domain
  /// entities.
  ///
  /// Any malformed persisted record causes [PersistenceRecordException] inside
  /// the persistence model, which the public operation guard translates into
  /// [CustodianRepositoryFailure].
  static Future<List<Custodian>> _loadAllCustodians(
    DatabaseClient databaseClient,
  ) async {
    final snapshots = await _store.find(databaseClient);

    return snapshots.map(_custodianFromSnapshot).toList(growable: false);
  }

  /// Creates the feature-specific failure returned when persistence
  /// infrastructure cannot complete an operation.
  static CustodianRepositoryFailure _persistenceFailure(String message) =>
      CustodianRepositoryFailure(message: message);

  /// Creates a new custodian snapshot differing in archive state and
  /// modification timestamp.
  static Custodian _withArchivedAt(
    Custodian custodian, {
    required DateTime? archivedAt,
    required DateTime modifiedAt,
  }) => Custodian(
    id: custodian.id,
    name: custodian.name,
    kind: custodian.kind,
    logo: custodian.logo,
    icon: custodian.icon,
    color: custodian.color,
    sortOrder: custodian.sortOrder,
    archivedAt: archivedAt,
    deletedAt: custodian.deletedAt,
    createdAt: custodian.createdAt,
    modifiedAt: modifiedAt,
    entityVersion: custodian.entityVersion,
  );

  /// Creates a new custodian snapshot differing only in deletion state.
  ///
  /// Custodian deletion does not alter [Custodian.modifiedAt]; the returned
  /// snapshot carries the deletion timestamp separately.
  static Custodian _withDeletedAt(Custodian custodian, DateTime? deletedAt) =>
      Custodian(
        id: custodian.id,
        name: custodian.name,
        kind: custodian.kind,
        logo: custodian.logo,
        icon: custodian.icon,
        color: custodian.color,
        sortOrder: custodian.sortOrder,
        archivedAt: custodian.archivedAt,
        deletedAt: deletedAt,
        createdAt: custodian.createdAt,
        modifiedAt: custodian.modifiedAt,
        entityVersion: custodian.entityVersion,
      );
}
