import 'package:axiom/src/core/identity/ids/jar_id.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record.dart';
import 'package:axiom/src/core/persistence/persistence_operation_guard.dart';
import 'package:axiom/src/core/persistence/sembast_stores.dart';
import 'package:axiom/src/core/ports/clock/clock_factory.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/jars/data/models/jar_persistence_model.dart';
import 'package:axiom/src/features/jars/domain/entities/jar.dart';
import 'package:axiom/src/features/jars/domain/enums/jar_kind.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_already_archived_failure.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_already_deleted_failure.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_already_exists_failure.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_failure.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_not_archived_failure.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_not_deleted_failure.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_not_found_failure.dart';
import 'package:axiom/src/features/jars/domain/failures/jar_repository_failure.dart';
import 'package:axiom/src/features/jars/domain/repositories/jar_repository.dart';
import 'package:sembast/sembast.dart';

/// Persists jars in the Sembast jars store.
///
/// The repository implements the storage-independent [JarRepository] contract
/// while keeping all Sembast details inside the data layer.
///
/// ## Identity
///
/// [Jar.id] is used as the Sembast record key.
///
/// Jar identity is therefore never duplicated inside the record value.
///
/// ## Deleted jars
///
/// Jar deletion is physical.
///
/// Deleted snapshots are returned to the caller but are not retained in the
/// jars store.
///
/// Restoration therefore requires the caller-retained deleted snapshot.
///
/// ## Archived jars
///
/// Archival differs from deletion.
///
/// Archived jars remain persisted and can be returned by [getAll], [getById],
/// [getByKind], [getArchived], and [search].
///
/// ## Target history
///
/// Every complete target history is persisted as part of the Jar aggregate.
///
/// The persistence model reconstructs the complete domain entity before it is
/// returned, causing current Jar invariants to be revalidated on every read.
///
/// ## Transactions
///
/// Write operations that depend on existing storage state use Sembast
/// transactions so validation and mutation occur atomically.
///
/// ## Failure translation
///
/// Expected persistence exceptions are translated to [JarRepositoryFailure]
/// through [guardPersistenceOperation].
///
/// Domain failures such as [JarNotFoundFailure] and
/// [JarAlreadyExistsFailure] remain explicit typed results.
///
/// Programmer errors and violated internal assumptions deliberately propagate.
final class SembastJarRepositoryImpl implements JarRepository {
  static final StoreRef<String, PersistenceRecord> _store = SembastStores.jars;

  final Database _database;

  /// Creates a jar repository backed by an already-open and validated
  /// [database].
  ///
  /// Database lifecycle ownership remains outside this repository.
  ///
  /// This repository never opens or closes the supplied database.
  // ignore: prefer_initializing_formals
  SembastJarRepositoryImpl({required Database database})
    : _database = database; // ignore: prefer_initializing_formals

  @override
  Future<Result<Jar, JarFailure>> archive(
    JarId id,
    DateTime archivedAt,
  ) => guardPersistenceOperation<Jar, JarFailure>(
    operation: () => _database.transaction((transaction) async {
      final record = _store.record(id.value);
      final persistedRecord = await record.get(transaction);

      if (persistedRecord == null) {
        return JarNotFoundFailure(message: 'Jar ID was not found: ${id.value}');
      }

      final jar = _jarFromRecord(recordKey: id.value, record: persistedRecord);

      if (jar.isArchived) {
        return JarAlreadyArchivedFailure(
          message: 'Jar is already archived: ${id.value}',
        );
      }

      final archivedJar = _withArchivedAt(
        jar,
        archivedAt: archivedAt,
        modifiedAt: archivedAt,
      );

      final model = JarPersistenceModel.fromEntity(archivedJar);

      await record.put(transaction, model.toRecord());

      return Success(archivedJar);
    }),
    persistenceFailure: _persistenceFailure,
    failureMessage: 'Unable to archive the jar.',
  );

  @override
  Future<Result<void, JarFailure>> create(Jar jar) {
    if (jar.isDeleted) {
      return Future.value(
        JarAlreadyDeletedFailure(
          message: 'Deleted jar cannot be created: ${jar.id.value}',
        ),
      );
    }

    if (jar.isArchived) {
      return Future.value(
        JarAlreadyArchivedFailure(
          message:
              'Archived jar cannot be created as a new jar: ${jar.id.value}',
        ),
      );
    }

    return guardPersistenceOperation<void, JarFailure>(
      operation: () => _database.transaction((transaction) async {
        final record = _store.record(jar.id.value);
        final existingRecord = await record.get(transaction);

        if (existingRecord != null) {
          return JarAlreadyExistsFailure(
            message: 'Jar ID already exists: ${jar.id.value}',
          );
        }

        final model = JarPersistenceModel.fromEntity(jar);

        await record.put(transaction, model.toRecord());

        return const Success(null);
      }),
      persistenceFailure: _persistenceFailure,
      failureMessage: 'Unable to create the jar.',
    );
  }

  @override
  Future<Result<Jar, JarFailure>> delete(
    JarId id,
  ) => guardPersistenceOperation<Jar, JarFailure>(
    operation: () => _database.transaction((transaction) async {
      final record = _store.record(id.value);
      final persistedRecord = await record.get(transaction);

      if (persistedRecord == null) {
        return JarNotFoundFailure(message: 'Jar ID was not found: ${id.value}');
      }

      final jar = _jarFromRecord(recordKey: id.value, record: persistedRecord);

      final deletedJar = _withDeletedAt(jar, createClock().nowUtc);

      await record.delete(transaction);

      return Success(deletedJar);
    }),
    persistenceFailure: _persistenceFailure,
    failureMessage: 'Unable to delete the jar.',
  );

  @override
  Future<Result<List<Jar>, JarFailure>> getActive() =>
      guardPersistenceOperation<List<Jar>, JarFailure>(
        operation: () async {
          final jars = await _loadAllJars(_database);

          final activeJars = jars
              .where((jar) => !jar.isArchived)
              .toList(growable: false);

          return Success(List<Jar>.unmodifiable(activeJars));
        },
        persistenceFailure: _persistenceFailure,
        failureMessage: 'Unable to load the active jars.',
      );

  @override
  Future<Result<List<Jar>, JarFailure>> getAll() =>
      guardPersistenceOperation<List<Jar>, JarFailure>(
        operation: () async {
          final jars = await _loadAllJars(_database);

          return Success(List<Jar>.unmodifiable(jars));
        },
        persistenceFailure: _persistenceFailure,
        failureMessage: 'Unable to load the jars.',
      );

  @override
  Future<Result<List<Jar>, JarFailure>> getArchived() =>
      guardPersistenceOperation<List<Jar>, JarFailure>(
        operation: () async {
          final jars = await _loadAllJars(_database);

          final archivedJars = jars
              .where((jar) => jar.isArchived)
              .toList(growable: false);

          return Success(List<Jar>.unmodifiable(archivedJars));
        },
        persistenceFailure: _persistenceFailure,
        failureMessage: 'Unable to load the archived jars.',
      );

  @override
  Future<Result<Jar?, JarFailure>> getById(JarId id) =>
      guardPersistenceOperation<Jar?, JarFailure>(
        operation: () async {
          final record = await _store.record(id.value).get(_database);

          if (record == null) {
            return const Success(null);
          }

          return Success(_jarFromRecord(recordKey: id.value, record: record));
        },
        persistenceFailure: _persistenceFailure,
        failureMessage: 'Unable to load the jar by ID.',
      );

  @override
  Future<Result<List<Jar>, JarFailure>> getByKind(JarKind kind) =>
      guardPersistenceOperation<List<Jar>, JarFailure>(
        operation: () async {
          final snapshots = await _store.find(
            _database,
            finder: Finder(
              filter: Filter.equals(JarPersistenceModel.kindField, kind.name),
            ),
          );

          final jars = snapshots.map(_jarFromSnapshot).toList(growable: false);

          return Success(List<Jar>.unmodifiable(jars));
        },
        persistenceFailure: _persistenceFailure,
        failureMessage: 'Unable to load jars by kind.',
      );

  @override
  Future<Result<void, JarFailure>> restore(Jar jar) {
    if (!jar.isDeleted) {
      return Future.value(
        JarNotDeletedFailure(message: 'Jar is not deleted: ${jar.id.value}'),
      );
    }

    return guardPersistenceOperation<void, JarFailure>(
      operation: () => _database.transaction((transaction) async {
        final record = _store.record(jar.id.value);
        final existingRecord = await record.get(transaction);

        if (existingRecord != null) {
          return JarAlreadyExistsFailure(
            message: 'Jar ID already exists: ${jar.id.value}',
          );
        }

        final restoredJar = _withDeletedAt(jar, null);

        final model = JarPersistenceModel.fromEntity(restoredJar);

        await record.put(transaction, model.toRecord());

        return const Success(null);
      }),
      persistenceFailure: _persistenceFailure,
      failureMessage: 'Unable to restore the jar.',
    );
  }

  @override
  Future<Result<List<Jar>, JarFailure>> search(String query) =>
      guardPersistenceOperation<List<Jar>, JarFailure>(
        operation: () async {
          final jars = await _loadAllJars(_database);

          final normalizedQuery = query.trim().toLowerCase();

          final matches = jars
              .where((jar) => jar.name.toLowerCase().contains(normalizedQuery))
              .toList(growable: false);

          return Success(List<Jar>.unmodifiable(matches));
        },
        persistenceFailure: _persistenceFailure,
        failureMessage: 'Unable to search jars.',
      );

  @override
  Future<Result<Jar, JarFailure>> unarchive(
    JarId id,
    DateTime modifiedAt,
  ) => guardPersistenceOperation<Jar, JarFailure>(
    operation: () => _database.transaction((transaction) async {
      final record = _store.record(id.value);
      final persistedRecord = await record.get(transaction);

      if (persistedRecord == null) {
        return JarNotFoundFailure(message: 'Jar ID was not found: ${id.value}');
      }

      final jar = _jarFromRecord(recordKey: id.value, record: persistedRecord);

      if (!jar.isArchived) {
        return JarNotArchivedFailure(
          message: 'Jar is not archived: ${id.value}',
        );
      }

      final unarchivedJar = _withArchivedAt(
        jar,
        archivedAt: null,
        modifiedAt: modifiedAt,
      );

      final model = JarPersistenceModel.fromEntity(unarchivedJar);

      await record.put(transaction, model.toRecord());

      return Success(unarchivedJar);
    }),
    persistenceFailure: _persistenceFailure,
    failureMessage: 'Unable to unarchive the jar.',
  );

  @override
  Future<Result<void, JarFailure>> update(Jar jar) {
    if (jar.isDeleted) {
      return Future.value(
        JarAlreadyDeletedFailure(
          message: 'Deleted jar cannot be updated: ${jar.id.value}',
        ),
      );
    }

    return guardPersistenceOperation<void, JarFailure>(
      operation: () => _database.transaction((transaction) async {
        final record = _store.record(jar.id.value);
        final existingRecord = await record.get(transaction);

        if (existingRecord == null) {
          return JarNotFoundFailure(
            message: 'Jar ID was not found: ${jar.id.value}',
          );
        }

        final model = JarPersistenceModel.fromEntity(jar);

        await record.put(transaction, model.toRecord());

        return const Success(null);
      }),
      persistenceFailure: _persistenceFailure,
      failureMessage: 'Unable to update the jar.',
    );
  }

  /// Reconstructs a jar from its persisted record key and value.
  static Jar _jarFromRecord({
    required String recordKey,
    required PersistenceRecord record,
  }) => JarPersistenceModel.fromRecord(
    recordKey: recordKey,
    record: record,
  ).toEntity();

  /// Reconstructs a jar from a Sembast record snapshot.
  static Jar _jarFromSnapshot(
    RecordSnapshot<String, PersistenceRecord> snapshot,
  ) => _jarFromRecord(recordKey: snapshot.key, record: snapshot.value);

  /// Loads every persisted jar and reconstructs the corresponding domain
  /// entities.
  ///
  /// Any malformed persisted record causes a persistence-record exception
  /// inside the persistence model, which the public operation guard translates
  /// into [JarRepositoryFailure].
  static Future<List<Jar>> _loadAllJars(DatabaseClient databaseClient) async {
    final snapshots = await _store.find(databaseClient);

    return snapshots.map(_jarFromSnapshot).toList(growable: false);
  }

  /// Creates the feature-specific failure returned when persistence
  /// infrastructure cannot complete an operation.
  static JarRepositoryFailure _persistenceFailure(String message) =>
      JarRepositoryFailure(message: message);

  /// Creates a new jar snapshot differing in archive state and modification
  /// timestamp.
  static Jar _withArchivedAt(
    Jar jar, {
    required DateTime? archivedAt,
    required DateTime modifiedAt,
  }) {
    return Jar(
      id: jar.id,
      name: jar.name,
      description: jar.description,
      kind: jar.kind,
      targets: jar.targets,
      icon: jar.icon,
      color: jar.color,
      sortOrder: jar.sortOrder,
      archivedAt: archivedAt,
      deletedAt: jar.deletedAt,
      createdAt: jar.createdAt,
      modifiedAt: modifiedAt,
      entityVersion: jar.entityVersion,
    );
  }

  /// Creates a new jar snapshot differing only in deletion state.
  ///
  /// Jar deletion does not alter [Jar.modifiedAt]; the returned snapshot
  /// carries the deletion timestamp separately.
  static Jar _withDeletedAt(Jar jar, DateTime? deletedAt) {
    return Jar(
      id: jar.id,
      name: jar.name,
      description: jar.description,
      kind: jar.kind,
      targets: jar.targets,
      icon: jar.icon,
      color: jar.color,
      sortOrder: jar.sortOrder,
      archivedAt: jar.archivedAt,
      deletedAt: deletedAt,
      createdAt: jar.createdAt,
      modifiedAt: jar.modifiedAt,
      entityVersion: jar.entityVersion,
    );
  }
}
