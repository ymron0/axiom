import 'package:axiom/src/core/domain/value_objects/calendar_date.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record.dart';
import 'package:axiom/src/core/persistence/persistence_operation_guard.dart';
import 'package:axiom/src/core/persistence/sembast_stores.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/balance_snapshots/data/models/balance_snapshot_persistence_model.dart';
import 'package:axiom/src/features/balance_snapshots/data/models/balance_snapshot_record_key.dart';
import 'package:axiom/src/features/balance_snapshots/domain/failures/balance_snapshot_failure.dart';
import 'package:axiom/src/features/balance_snapshots/domain/failures/balance_snapshot_persistence_failure.dart';
import 'package:axiom/src/features/balance_snapshots/domain/repositories/balance_snapshot_repository.dart';
import 'package:axiom/src/features/balance_snapshots/domain/value_objects/balance_snapshot.dart';
import 'package:axiom/src/features/balance_snapshots/domain/value_objects/balance_snapshot_date_range.dart';
import 'package:axiom/src/features/balance_snapshots/domain/value_objects/balance_snapshot_subject.dart';
import 'package:sembast/sembast.dart';

/// Sembast-backed implementation of [BalanceSnapshotRepository].
///
/// ## Natural identity
///
/// Each snapshot is persisted under the natural key produced by
/// [BalanceSnapshotRecordKey]:
///
/// ```text
/// subject type + subject ID + snapshot date
/// ```
///
/// Because that natural key is the Sembast record key, persistence can contain
/// at most one repository-created snapshot for a subject and date.
///
/// ## Save semantics
///
/// [save] uses direct natural-key replacement inside a Sembast transaction.
///
/// It deliberately does not perform a create-versus-update decision first.
/// Writing the same natural key replaces the existing record atomically.
///
/// Therefore:
///
/// - first writes insert;
/// - repeated writes are idempotent;
/// - historical rebuilds replace the previous derived snapshot;
/// - duplicate daily records cannot be produced through this repository.
///
/// ## Queries
///
/// Exact-date queries use the natural record key directly.
///
/// Range and latest queries use the redundant [BalanceSnapshotPersistenceModel
/// .subjectKeyField] and
/// [BalanceSnapshotPersistenceModel.snapshotDateEpochDayField] values written
/// by the persistence model.
///
/// Range results are explicitly sorted oldest-to-newest.
///
/// A secondary record-key ordering is included so persistence ordering remains
/// deterministic even if corrupt data somehow produces equal date indexes.
///
/// ## Failure translation
///
/// Malformed persisted records are rejected by
/// [BalanceSnapshotPersistenceModel].
///
/// Expected mapping, database, and file-system errors are translated into
/// [BalanceSnapshotPersistenceFailure] by [guardPersistenceOperation].
///
/// Missing records are not failures:
///
/// - [getByDate] returns successful `null`;
/// - [getLatest] returns successful `null`;
/// - [getByDateRange] returns an empty immutable list.
final class SembastBalanceSnapshotRepositoryImpl
    implements BalanceSnapshotRepository {
  static final StoreRef<String, PersistenceRecord> _store =
      SembastStores.balanceSnapshots;

  final Database _database;

  /// Creates a balance-snapshot repository backed by an already-open database.
  ///
  /// Database lifecycle ownership remains outside this repository.
  // ignore: prefer_initializing_formals
  SembastBalanceSnapshotRepositoryImpl({required Database database})
    : _database = database; // ignore: prefer_initializing_formals

  @override
  Future<Result<BalanceSnapshot?, BalanceSnapshotFailure>> getByDate({
    required BalanceSnapshotSubject subject,
    required CalendarDate snapshotDate,
  }) => guardPersistenceOperation<BalanceSnapshot?, BalanceSnapshotFailure>(
    operation: () async {
      final key = BalanceSnapshotRecordKey.fromSubject(
        subject: subject,
        snapshotDate: snapshotDate,
      );

      final record = await _store.record(key.value).get(_database);

      if (record == null) {
        return const Success(null);
      }

      final snapshot = _snapshotFromRecord(
        recordKey: key.value,
        record: record,
      );

      return Success(snapshot);
    },
    persistenceFailure: _persistenceFailure,
    failureMessage: 'Unable to load the balance snapshot by date.',
  );

  @override
  Future<Result<List<BalanceSnapshot>, BalanceSnapshotFailure>> getByDateRange({
    required BalanceSnapshotSubject subject,
    required BalanceSnapshotDateRange range,
  }) =>
      guardPersistenceOperation<List<BalanceSnapshot>, BalanceSnapshotFailure>(
        operation: () async {
          if (range.isEmpty) {
            return const Success(<BalanceSnapshot>[]);
          }

          final subjectKey = _subjectKey(subject);
          final fromEpochDay = _epochDay(range.from);
          final untilEpochDay = _epochDay(range.until);

          final records = await _store.find(
            _database,
            finder: Finder(
              filter: Filter.and(<Filter>[
                Filter.equals(
                  BalanceSnapshotPersistenceModel.subjectKeyField,
                  subjectKey,
                ),
                Filter.greaterThanOrEquals(
                  BalanceSnapshotPersistenceModel.snapshotDateEpochDayField,
                  fromEpochDay,
                ),
                Filter.lessThan(
                  BalanceSnapshotPersistenceModel.snapshotDateEpochDayField,
                  untilEpochDay,
                ),
              ]),
              sortOrders: <SortOrder<Object?>>[
                SortOrder<Object?>(
                  BalanceSnapshotPersistenceModel.snapshotDateEpochDayField,
                ),
                SortOrder<Object?>(Field.key),
              ],
            ),
          );

          final snapshots = records
              .map(_snapshotFromRecordSnapshot)
              .toList(growable: false);

          return Success(List<BalanceSnapshot>.unmodifiable(snapshots));
        },
        persistenceFailure: _persistenceFailure,
        failureMessage: 'Unable to load balance snapshots by date range.',
      );

  @override
  Future<Result<BalanceSnapshot?, BalanceSnapshotFailure>> getLatest(
    BalanceSnapshotSubject subject,
  ) => guardPersistenceOperation<BalanceSnapshot?, BalanceSnapshotFailure>(
    operation: () async {
      final records = await _store.find(
        _database,
        finder: Finder(
          filter: Filter.equals(
            BalanceSnapshotPersistenceModel.subjectKeyField,
            _subjectKey(subject),
          ),
          sortOrders: <SortOrder<Object?>>[
            SortOrder<Object?>(
              BalanceSnapshotPersistenceModel.snapshotDateEpochDayField,
              false,
            ),
            SortOrder<Object?>(Field.key),
          ],
          limit: 1,
        ),
      );

      if (records.isEmpty) {
        return const Success(null);
      }

      return Success(_snapshotFromRecordSnapshot(records.single));
    },
    persistenceFailure: _persistenceFailure,
    failureMessage: 'Unable to load the latest balance snapshot.',
  );

  @override
  Future<Result<void, BalanceSnapshotFailure>> save(BalanceSnapshot snapshot) =>
      guardPersistenceOperation<void, BalanceSnapshotFailure>(
        operation: () => _database.transaction((transaction) async {
          final model = BalanceSnapshotPersistenceModel.fromEntity(snapshot);

          await _store
              .record(model.recordKey)
              .put(transaction, model.toRecord());

          return const Success(null);
        }),
        persistenceFailure: _persistenceFailure,
        failureMessage: 'Unable to save the balance snapshot.',
      );

  /// Converts a date-only domain value into the persisted numeric day index.
  static int _epochDay(CalendarDate date) {
    return date.toDateTimeUtc().millisecondsSinceEpoch ~/
        Duration.millisecondsPerDay;
  }

  /// Creates the feature-specific persistence failure.
  static BalanceSnapshotPersistenceFailure _persistenceFailure(String message) {
    return BalanceSnapshotPersistenceFailure(message: message);
  }

  /// Reconstructs a domain snapshot from a persisted record.
  static BalanceSnapshot _snapshotFromRecord({
    required String recordKey,
    required PersistenceRecord record,
  }) {
    return BalanceSnapshotPersistenceModel.fromRecord(
      recordKey: recordKey,
      record: record,
    ).toEntity();
  }

  /// Reconstructs a domain snapshot from a Sembast record snapshot.
  static BalanceSnapshot _snapshotFromRecordSnapshot(
    RecordSnapshot<String, PersistenceRecord> snapshot,
  ) {
    return _snapshotFromRecord(recordKey: snapshot.key, record: snapshot.value);
  }

  /// Produces the same stable subject-only lookup key used by
  /// [BalanceSnapshotPersistenceModel].
  ///
  /// Subject type remains part of the key, so equal serialized IDs belonging
  /// to different subject types cannot collide.
  static String _subjectKey(BalanceSnapshotSubject subject) {
    final accountId = subject.accountId;

    if (accountId != null) {
      return '${BalanceSnapshotRecordKey.accountType}|'
          '${Uri.encodeComponent(accountId.value)}';
    }

    final custodianId = subject.custodianId;

    if (custodianId != null) {
      return '${BalanceSnapshotRecordKey.custodianType}|'
          '${Uri.encodeComponent(custodianId.value)}';
    }

    final jarId = subject.jarId!;

    return '${BalanceSnapshotRecordKey.jarType}|'
        '${Uri.encodeComponent(jarId.value)}';
  }
}
