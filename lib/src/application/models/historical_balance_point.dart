import 'package:axiom/src/core/domain/value_objects/calendar_date.dart';
import 'package:axiom/src/features/balance_snapshots/domain/value_objects/balance_snapshot.dart';
import 'package:axiom/src/features/balance_snapshots/domain/value_objects/balance_snapshot_subject.dart';

/// A single point in a historical balance time series.
///
/// A point always represents one requested calendar date.
///
/// When [snapshot] is non-null, a balance snapshot exists for [date].
/// When [snapshot] is null, the requested date has no captured snapshot.
///
/// Missing points are deliberately represented instead of substituting an
/// earlier snapshot. This allows callers such as charts to distinguish:
///
/// - an actual recorded balance;
/// - a day for which no snapshot exists.
///
/// The snapshot remains the authoritative source for the actual balance
/// amounts when the point is available.
final class HistoricalBalancePoint {
  HistoricalBalancePoint.available(BalanceSnapshot snapshot)
    : subject = snapshot.subject,
      date = snapshot.snapshotDate,
      snapshot = snapshot;

  HistoricalBalancePoint.missing({required this.subject, required this.date})
    : snapshot = null;

  /// Subject whose historical balance is represented.
  final BalanceSnapshotSubject subject;

  /// Calendar date represented by this point.
  final CalendarDate date;

  /// Snapshot captured for [date], or `null` when that day is missing.
  final BalanceSnapshot? snapshot;

  /// Whether no snapshot exists for this requested date.
  bool get isMissing => snapshot == null;
}
