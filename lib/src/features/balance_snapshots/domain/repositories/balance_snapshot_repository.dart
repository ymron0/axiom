// coverage:ignore-file

import 'package:axiom/src/core/domain/value_objects/calendar_date.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/balance_snapshots/domain/failures/balance_snapshot_failure.dart';
import 'package:axiom/src/features/balance_snapshots/domain/value_objects/balance_snapshot.dart';
import 'package:axiom/src/features/balance_snapshots/domain/value_objects/balance_snapshot_date_range.dart';
import 'package:axiom/src/features/balance_snapshots/domain/value_objects/balance_snapshot_subject.dart';

/// Storage-independent repository contract for daily balance snapshots.
///
/// Balance snapshots are derived historical projections rather than
/// authoritative financial records.
///
/// Transactions, ledger entries, and transaction allocations remain the source
/// of truth. Snapshots may therefore be overwritten or rebuilt whenever
/// historical financial state changes.
///
/// ## Natural identity
///
/// A persisted daily snapshot is uniquely identified by:
///
/// ```text
/// subject type + subject ID + snapshot date
/// ```
///
/// For example:
///
/// ```text
/// account / account-123 / 2026-09-19
/// custodian / custodian-123 / 2026-09-19
/// jar / jar-123 / 2026-09-19
/// ```
///
/// Subject type is part of the key. Therefore an account and custodian whose
/// typed IDs happen to contain the same serialized value remain distinct
/// snapshot subjects.
///
/// [BalanceSnapshot.capturedAt] is deliberately not part of identity.
///
/// Rebuilding a snapshot for the same subject and date produces another
/// representation of the same derived historical position rather than a new
/// independent record.
///
/// ## Save semantics
///
/// [save] uses natural-key replacement semantics.
///
/// When no snapshot exists for the supplied subject and date, the snapshot is
/// stored.
///
/// When a snapshot already exists for the same subject and date, that stored
/// snapshot is replaced.
///
/// Consequently:
///
/// - repeated writes never create duplicate daily snapshots;
/// - saving the same snapshot repeatedly is idempotent;
/// - rebuilding a historical snapshot replaces its previous projection;
/// - callers do not need to choose between create and update operations.
///
/// Implementations must perform the natural-key lookup and replacement as one
/// logical write operation.
///
/// ## Duplicate prevention
///
/// Persistence must contain at most one snapshot for any natural key.
///
/// Implementations must enforce this invariant independently of storage
/// technology. A relational unique constraint, document key, composite key,
/// in-memory map key, or equivalent mechanism may be used internally, but such
/// details must not leak through this interface.
///
/// Repository methods must never arbitrarily choose between duplicate records
/// if underlying storage is found to violate this invariant. Such corruption
/// must be surfaced as a [BalanceSnapshotFailure].
///
/// ## Exact-date lookup
///
/// [getByDate] resolves one natural key.
///
/// Absence is normal and is represented by a successful `null` result.
///
/// ## Range queries
///
/// [getByDateRange] returns snapshots belonging only to the requested subject.
///
/// [BalanceSnapshotDateRange.from] is inclusive and
/// [BalanceSnapshotDateRange.until] is exclusive.
///
/// Results are ordered strictly by [BalanceSnapshot.snapshotDate] ascending,
/// from oldest to newest.
///
/// An empty matching range succeeds with an empty list.
///
/// ## Latest lookup
///
/// [getLatest] returns the snapshot having the greatest
/// [BalanceSnapshot.snapshotDate] for the supplied subject.
///
/// "Latest" refers exclusively to the represented snapshot date.
///
/// [BalanceSnapshot.capturedAt] must not influence this lookup. A historical
/// snapshot rebuilt today does not thereby become the subject's latest daily
/// snapshot.
///
/// Absence is normal and is represented by a successful `null` result.
///
/// ## Categories and budgets
///
/// Categories and budgets cannot be queried through this repository because
/// [BalanceSnapshotSubject] cannot represent either domain concept.
///
/// Their historical reporting remains transaction-derived.
///
/// ## Contract
///
/// Implementations must:
///
/// - preserve [BalanceSnapshot] domain invariants;
/// - use subject type, subject ID, and date as the natural key;
/// - prevent duplicate natural keys;
/// - make [save] idempotent with respect to that natural key;
/// - deterministically replace an existing snapshot during rebuild;
/// - preserve exact calendar dates without timezone conversion;
/// - return date-range results oldest-to-newest;
/// - determine latest snapshots by snapshot date rather than capture time;
/// - expose no persistence-specific objects or exceptions; and
/// - return expected failures through [BalanceSnapshotFailure].
abstract interface class BalanceSnapshotRepository {
  /// Stores or replaces [snapshot] using its natural daily key.
  ///
  /// The natural key is:
  ///
  /// ```text
  /// snapshot.subject + snapshot.snapshotDate
  /// ```
  ///
  /// When no record exists for that key, [snapshot] is inserted.
  ///
  /// When a record already exists for that key, it is replaced by [snapshot].
  ///
  /// The operation must never create a second snapshot for the same natural
  /// key.
  ///
  /// Calling this method repeatedly with the same [snapshot] produces the same
  /// persisted state.
  Future<Result<void, BalanceSnapshotFailure>> save(BalanceSnapshot snapshot);

  /// Returns the snapshot for [subject] on exactly [snapshotDate].
  ///
  /// No earlier or later snapshot may be substituted.
  ///
  /// Returns a successful `null` result when no snapshot exists for that exact
  /// subject and date.
  Future<Result<BalanceSnapshot?, BalanceSnapshotFailure>> getByDate({
    required BalanceSnapshotSubject subject,
    required CalendarDate snapshotDate,
  });

  /// Returns snapshots for [subject] whose dates belong to [range].
  ///
  /// The lower bound is inclusive and the upper bound is exclusive:
  ///
  /// ```text
  /// range.from <= snapshot.snapshotDate < range.until
  /// ```
  ///
  /// Results are ordered by [BalanceSnapshot.snapshotDate] ascending.
  ///
  /// Returns an empty list when no snapshots match.
  Future<Result<List<BalanceSnapshot>, BalanceSnapshotFailure>> getByDateRange({
    required BalanceSnapshotSubject subject,
    required BalanceSnapshotDateRange range,
  });

  /// Returns the most recent snapshot stored for [subject].
  ///
  /// The result is the snapshot having the greatest
  /// [BalanceSnapshot.snapshotDate].
  ///
  /// [BalanceSnapshot.capturedAt] does not participate in latest-snapshot
  /// selection.
  ///
  /// Returns a successful `null` result when the subject has no snapshots.
  Future<Result<BalanceSnapshot?, BalanceSnapshotFailure>> getLatest(
    BalanceSnapshotSubject subject,
  );
}
