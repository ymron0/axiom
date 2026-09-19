import 'package:axiom/src/core/domain/value_objects/calendar_date.dart';

/// Calendar-date range used when querying daily balance snapshots.
///
/// ## Boundary semantics
///
/// [from] is inclusive.
///
/// [until] is exclusive.
///
/// For example:
///
/// ```text
/// from:  2026-07-01
/// until: 2026-08-01
/// ```
///
/// includes every daily snapshot from July 1 through July 31.
///
/// Using an exclusive upper bound matches the temporal-query conventions used
/// elsewhere in the domain and makes adjacent ranges compose without overlap:
///
/// ```text
/// [2026-07-01, 2026-08-01)
/// [2026-08-01, 2026-09-01)
/// ```
///
/// ## Empty ranges
///
/// [from] may equal [until]. Such a range is valid and contains no dates.
///
/// ## Invariants
///
/// [until] cannot occur before [from].
final class BalanceSnapshotDateRange {
  /// Inclusive first date in the range.
  final CalendarDate from;

  /// Exclusive first date outside the range.
  final CalendarDate until;

  /// Creates a calendar-date range.
  ///
  /// Throws an [ArgumentError] when [until] occurs before [from].
  BalanceSnapshotDateRange({required this.from, required this.until}) {
    if (until.isBefore(from)) {
      throw ArgumentError.value(
        until,
        'until',
        'Snapshot range end date cannot precede its start date.',
      );
    }
  }

  /// Whether this range contains no calendar dates.
  bool get isEmpty => from == until;

  /// Whether [date] belongs to this range.
  bool contains(CalendarDate date) {
    return date.isOnOrAfter(from) && date.isBefore(until);
  }
}
