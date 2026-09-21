import 'package:axiom/src/core/identity/ids/account_id.dart';
import 'package:axiom/src/core/identity/ids/category_id.dart';
import 'package:axiom/src/core/identity/ids/jar_id.dart';
import 'package:axiom/src/core/identity/ids/merchant_id.dart';
import 'package:axiom/src/core/identity/ids/transaction_series_id.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record.dart';
import 'package:axiom/src/core/persistence/persistence_operation_guard.dart';
import 'package:axiom/src/core/persistence/sembast_stores.dart';
import 'package:axiom/src/core/ports/clock/clock_factory.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/transactions/data/models/transaction_series_persistence_model.dart';
import 'package:axiom/src/features/transactions/domain/entities/transaction_series.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_series_already_archived_failure.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_series_already_deleted_failure.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_series_already_exists_failure.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_series_failure.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_series_not_archived_failure.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_series_not_deleted_failure.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_series_not_found_failure.dart';
import 'package:axiom/src/features/transactions/domain/failures/transaction_series_repository_failure.dart';
import 'package:axiom/src/features/transactions/domain/repositories/transaction_series_repository.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/transaction_template.dart';
import 'package:sembast/sembast.dart';

/// Persists recurring transaction-series definitions in Sembast.
///
/// This implementation preserves the complete storage-independent
/// [TransactionSeriesRepository] contract.
///
/// ## Persistence ownership
///
/// This repository stores only recurrence definitions.
///
/// Generated transactions remain independently persisted transactions and are
/// not created, deleted, or restored through this repository.
///
/// ## Lifecycle
///
/// Active, paused, and archived series are persisted.
///
/// Archiving always pauses a series.
///
/// Unarchiving removes archival state but preserves pause state. Explicit resume
/// is therefore required before generation becomes enabled again.
///
/// Deletion is physical. [delete] removes the persisted record and returns a
/// caller-owned snapshot carrying a deletion timestamp.
///
/// [restore] clears that deletion timestamp before reinserting the series.
///
/// Existing pause and archival state are retained during delete and restore.
///
/// ## Reference queries
///
/// Account, merchant, category, and jar existence checks inspect:
///
/// - the normal series transaction template; and
/// - every recurrence-exception replacement template.
///
/// Both active and archived series participate in these checks.
///
/// ## Failure translation
///
/// Storage exceptions and malformed persisted records are translated into
/// [TransactionSeriesRepositoryFailure].
///
/// Domain lifecycle and identity conditions remain explicit typed failures.
///
/// ## Collection semantics
///
/// All returned collections are immutable.
final class SembastTransactionSeriesRepositoryImpl
    implements TransactionSeriesRepository {
  static final StoreRef<String, PersistenceRecord> _store =
      SembastStores.transactionSeries;

  final Database _database;

  /// Creates a repository backed by an already-open [database].
  ///
  /// Database lifecycle ownership remains outside this repository.
  // ignore: prefer_initializing_formals
  SembastTransactionSeriesRepositoryImpl({required Database database})
    : _database = database; // ignore: prefer_initializing_formals

  @override
  Future<Result<void, TransactionSeriesFailure>> create(
    TransactionSeries series,
  ) {
    if (series.isDeleted) {
      return Future.value(
        TransactionSeriesAlreadyDeletedFailure(
          message:
              'Deleted transaction series cannot be created: '
              '${series.id.value}',
        ),
      );
    }

    if (series.isArchived) {
      return Future.value(
        TransactionSeriesAlreadyArchivedFailure(
          message:
              'Archived transaction series cannot be created: '
              '${series.id.value}',
        ),
      );
    }

    return guardPersistenceOperation<void, TransactionSeriesFailure>(
      operation: () => _database.transaction((transaction) async {
        final record = _store.record(series.id.value);

        if (await record.exists(transaction)) {
          return TransactionSeriesAlreadyExistsFailure(
            message:
                'Transaction series ID already exists: '
                '${series.id.value}',
          );
        }

        final model = TransactionSeriesPersistenceModel.fromEntity(series);

        await record.put(transaction, model.toRecord());

        return const Success(null);
      }),
      persistenceFailure: _persistenceFailure,
      failureMessage: 'Unable to create the transaction series.',
    );
  }

  @override
  Future<Result<List<TransactionSeries>, TransactionSeriesFailure>> getAll() {
    return guardPersistenceOperation<
      List<TransactionSeries>,
      TransactionSeriesFailure
    >(
      operation: () async {
        final series = await _loadAllSeries(_database);

        return Success(List<TransactionSeries>.unmodifiable(series));
      },
      persistenceFailure: _persistenceFailure,
      failureMessage: 'Unable to load transaction series.',
    );
  }

  @override
  Future<Result<List<TransactionSeries>, TransactionSeriesFailure>>
  getActive() {
    return _findWhere((series) => !series.isArchived);
  }

  @override
  Future<Result<List<TransactionSeries>, TransactionSeriesFailure>>
  getArchived() {
    return _findWhere((series) => series.isArchived);
  }

  @override
  Future<Result<TransactionSeries?, TransactionSeriesFailure>> getById(
    TransactionSeriesId id,
  ) {
    return guardPersistenceOperation<
      TransactionSeries?,
      TransactionSeriesFailure
    >(
      operation: () async {
        final record = await _store.record(id.value).get(_database);

        if (record == null) {
          return const Success(null);
        }

        return Success(_seriesFromRecord(recordKey: id.value, record: record));
      },
      persistenceFailure: _persistenceFailure,
      failureMessage: 'Unable to load the transaction series by ID.',
    );
  }

  @override
  Future<Result<bool, TransactionSeriesFailure>> existsByAccountId(
    AccountId accountId,
  ) {
    return _existsWhere(
      (series) => _templatesOf(series).any(
        (template) =>
            template.ledgerEntries.any((entry) => entry.accountId == accountId),
      ),
    );
  }

  @override
  Future<Result<bool, TransactionSeriesFailure>> existsByMerchantId(
    MerchantId merchantId,
  ) {
    return _existsWhere(
      (series) => _templatesOf(
        series,
      ).any((template) => template.merchantId == merchantId),
    );
  }

  @override
  Future<Result<bool, TransactionSeriesFailure>> existsByCategoryId(
    CategoryId categoryId,
  ) {
    return _existsWhere(
      (series) => _templatesOf(series).any(
        (template) =>
            template.splits.any((split) => split.categoryId == categoryId),
      ),
    );
  }

  @override
  Future<Result<bool, TransactionSeriesFailure>> existsByJarId(JarId jarId) {
    return _existsWhere(
      (series) => _templatesOf(
        series,
      ).any((template) => template.splits.any((split) => split.jarId == jarId)),
    );
  }

  @override
  Future<Result<void, TransactionSeriesFailure>> update(
    TransactionSeries series,
  ) {
    if (series.isDeleted) {
      return Future.value(
        TransactionSeriesAlreadyDeletedFailure(
          message:
              'Deleted transaction series cannot be updated: '
              '${series.id.value}',
        ),
      );
    }

    return guardPersistenceOperation<void, TransactionSeriesFailure>(
      operation: () => _database.transaction((transaction) async {
        final record = _store.record(series.id.value);
        final existingRecord = await record.get(transaction);

        if (existingRecord == null) {
          return _notFound(series.id);
        }

        // Reconstruct the existing series before replacement. This ensures a
        // corrupt persisted record cannot be silently overwritten by update.
        _seriesFromRecord(recordKey: series.id.value, record: existingRecord);

        final model = TransactionSeriesPersistenceModel.fromEntity(series);

        await record.put(transaction, model.toRecord());

        return const Success(null);
      }),
      persistenceFailure: _persistenceFailure,
      failureMessage: 'Unable to update the transaction series.',
    );
  }

  @override
  Future<Result<TransactionSeries, TransactionSeriesFailure>> archive(
    TransactionSeriesId id,
    DateTime archivedAt,
  ) {
    return guardPersistenceOperation<
      TransactionSeries,
      TransactionSeriesFailure
    >(
      operation: () => _database.transaction((transaction) async {
        final record = _store.record(id.value);
        final persistedRecord = await record.get(transaction);

        if (persistedRecord == null) {
          return _notFound(id);
        }

        final series = _seriesFromRecord(
          recordKey: id.value,
          record: persistedRecord,
        );

        if (series.isArchived) {
          return TransactionSeriesAlreadyArchivedFailure(
            message:
                'Transaction series is already archived: '
                '${id.value}',
          );
        }

        final archivedSeries = _withArchivedAt(
          series,
          archivedAt: archivedAt,
          modifiedAt: archivedAt,
        );

        await record.put(
          transaction,
          TransactionSeriesPersistenceModel.fromEntity(
            archivedSeries,
          ).toRecord(),
        );

        return Success(archivedSeries);
      }),
      persistenceFailure: _persistenceFailure,
      failureMessage: 'Unable to archive the transaction series.',
    );
  }

  @override
  Future<Result<TransactionSeries, TransactionSeriesFailure>> unarchive(
    TransactionSeriesId id,
    DateTime modifiedAt,
  ) {
    return guardPersistenceOperation<
      TransactionSeries,
      TransactionSeriesFailure
    >(
      operation: () => _database.transaction((transaction) async {
        final record = _store.record(id.value);
        final persistedRecord = await record.get(transaction);

        if (persistedRecord == null) {
          return _notFound(id);
        }

        final series = _seriesFromRecord(
          recordKey: id.value,
          record: persistedRecord,
        );

        if (!series.isArchived) {
          return TransactionSeriesNotArchivedFailure(
            message:
                'Transaction series is not archived: '
                '${id.value}',
          );
        }

        final unarchivedSeries = _withArchivedAt(
          series,
          archivedAt: null,
          modifiedAt: modifiedAt,
        );

        await record.put(
          transaction,
          TransactionSeriesPersistenceModel.fromEntity(
            unarchivedSeries,
          ).toRecord(),
        );

        return Success(unarchivedSeries);
      }),
      persistenceFailure: _persistenceFailure,
      failureMessage: 'Unable to unarchive the transaction series.',
    );
  }

  @override
  Future<Result<TransactionSeries, TransactionSeriesFailure>> delete(
    TransactionSeriesId id,
  ) {
    return guardPersistenceOperation<
      TransactionSeries,
      TransactionSeriesFailure
    >(
      operation: () => _database.transaction((transaction) async {
        final record = _store.record(id.value);
        final persistedRecord = await record.get(transaction);

        if (persistedRecord == null) {
          return _notFound(id);
        }

        final series = _seriesFromRecord(
          recordKey: id.value,
          record: persistedRecord,
        );

        final deletedSeries = _withDeletedAt(series, createClock().nowUtc);

        await record.delete(transaction);

        return Success(deletedSeries);
      }),
      persistenceFailure: _persistenceFailure,
      failureMessage: 'Unable to delete the transaction series.',
    );
  }

  @override
  Future<Result<void, TransactionSeriesFailure>> restore(
    TransactionSeries series,
  ) {
    if (!series.isDeleted) {
      return Future.value(
        TransactionSeriesNotDeletedFailure(
          message:
              'Transaction series is not deleted: '
              '${series.id.value}',
        ),
      );
    }

    final restoredSeries = _withDeletedAt(series, null);

    return guardPersistenceOperation<void, TransactionSeriesFailure>(
      operation: () => _database.transaction((transaction) async {
        final record = _store.record(series.id.value);

        if (await record.exists(transaction)) {
          return TransactionSeriesAlreadyExistsFailure(
            message:
                'Transaction series ID already exists: '
                '${series.id.value}',
          );
        }

        final model = TransactionSeriesPersistenceModel.fromEntity(
          restoredSeries,
        );

        await record.put(transaction, model.toRecord());

        return const Success(null);
      }),
      persistenceFailure: _persistenceFailure,
      failureMessage: 'Unable to restore the transaction series.',
    );
  }

  /// Returns immutable persisted series satisfying [matches].
  Future<Result<List<TransactionSeries>, TransactionSeriesFailure>> _findWhere(
    bool Function(TransactionSeries series) matches,
  ) {
    return guardPersistenceOperation<
      List<TransactionSeries>,
      TransactionSeriesFailure
    >(
      operation: () async {
        final series = await _loadAllSeries(_database);

        return Success(
          List<TransactionSeries>.unmodifiable(series.where(matches)),
        );
      },
      persistenceFailure: _persistenceFailure,
      failureMessage: 'Unable to query transaction series.',
    );
  }

  /// Determines whether any persisted transaction series satisfies [matches].
  ///
  /// Every persisted series is fully reconstructed before matching. Corrupt
  /// recurrence data therefore fails closed instead of making a referenced
  /// domain entity appear safe to delete.
  Future<Result<bool, TransactionSeriesFailure>> _existsWhere(
    bool Function(TransactionSeries series) matches,
  ) {
    return guardPersistenceOperation<bool, TransactionSeriesFailure>(
      operation: () async {
        final series = await _loadAllSeries(_database);

        return Success(series.any(matches));
      },
      persistenceFailure: _persistenceFailure,
      failureMessage: 'Unable to inspect transaction-series references.',
    );
  }

  /// Yields every transaction template capable of referencing another entity.
  ///
  /// The normal template is yielded first, followed by replacement templates
  /// declared by recurrence exceptions.
  static Iterable<TransactionTemplate> _templatesOf(
    TransactionSeries series,
  ) sync* {
    yield series.template;

    for (final exception in series.exceptions) {
      final replacementTemplate = exception.replacementTemplate;

      if (replacementTemplate != null) {
        yield replacementTemplate;
      }
    }
  }

  static TransactionSeries _seriesFromRecord({
    required String recordKey,
    required PersistenceRecord record,
  }) {
    return TransactionSeriesPersistenceModel.fromRecord(
      recordKey: recordKey,
      record: record,
    ).toEntity();
  }

  static TransactionSeries _seriesFromSnapshot(
    RecordSnapshot<String, PersistenceRecord> snapshot,
  ) {
    return _seriesFromRecord(recordKey: snapshot.key, record: snapshot.value);
  }

  static Future<List<TransactionSeries>> _loadAllSeries(
    DatabaseClient databaseClient,
  ) async {
    final snapshots = await _store.find(databaseClient);

    return snapshots.map(_seriesFromSnapshot).toList(growable: false);
  }

  static TransactionSeriesRepositoryFailure _persistenceFailure(
    String message,
  ) {
    return TransactionSeriesRepositoryFailure(message: message);
  }

  static TransactionSeriesNotFoundFailure _notFound(TransactionSeriesId id) {
    return TransactionSeriesNotFoundFailure(
      message:
          'Transaction series ID was not found: '
          '${id.value}',
    );
  }

  /// Creates a series snapshot differing in archival state and modification
  /// timestamp.
  ///
  /// Archiving always pauses the resulting series. Removing archival state
  /// preserves the existing pause state.
  static TransactionSeries _withArchivedAt(
    TransactionSeries series, {
    required DateTime? archivedAt,
    required DateTime modifiedAt,
  }) {
    return TransactionSeries(
      id: series.id,
      template: series.template,
      recurrenceRule: series.recurrenceRule,
      exceptions: series.exceptions,
      isPaused: archivedAt != null || series.isPaused,
      archivedAt: archivedAt,
      deletedAt: series.deletedAt,
      createdAt: series.createdAt,
      modifiedAt: modifiedAt,
      entityVersion: series.entityVersion,
    );
  }

  /// Creates a series snapshot differing only in deletion state.
  ///
  /// Physical deletion does not modify [TransactionSeries.modifiedAt].
  ///
  /// Pause state is preserved through deletion and restoration.
  static TransactionSeries _withDeletedAt(
    TransactionSeries series,
    DateTime? deletedAt,
  ) {
    return TransactionSeries(
      id: series.id,
      template: series.template,
      recurrenceRule: series.recurrenceRule,
      exceptions: series.exceptions,
      isPaused: series.isPaused,
      archivedAt: series.archivedAt,
      deletedAt: deletedAt,
      createdAt: series.createdAt,
      modifiedAt: series.modifiedAt,
      entityVersion: series.entityVersion,
    );
  }
}
