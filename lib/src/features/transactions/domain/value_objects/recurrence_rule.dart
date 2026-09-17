import 'package:axiom/src/core/domain/value_objects/calendar_date.dart';
import 'package:axiom/src/features/transactions/domain/enums/recurrence_frequency.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/recurrence_end.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'recurrence_rule.mapper.dart';

/// Defines the calendar recurrence of a transaction series.
///
/// A recurrence rule determines scheduled calendar dates only.
///
/// It does not:
///
/// - create transactions;
/// - own transaction identity;
/// - evaluate cumulative monetary progress;
/// - attach recurrence metadata to generated transactions.
///
/// ## Anchoring
///
/// [startsOn] is occurrence index `0`.
///
/// [interval] counts units of [frequency].
///
/// For example:
///
/// ```text
/// daily   + interval 2 = every second day
/// weekly  + interval 2 = every second week
/// monthly + interval 3 = every third month
/// yearly  + interval 2 = every second year
/// ```
///
/// ## Monthly semantics
///
/// Monthly recurrence remains anchored to the original [startsOn] day.
///
/// When the target month does not contain that day, the occurrence is clamped
/// to the final calendar day of the target month. The original anchor remains
/// unchanged for later months.
///
/// For example:
///
/// ```text
/// 2026-01-31
/// 2026-02-28
/// 2026-03-31
/// 2026-04-30
/// ```
///
/// ## Yearly semantics
///
/// Yearly recurrence keeps the original month and day.
///
/// An unavailable day is clamped to the final day of that month.
///
/// A recurrence beginning on February 29 therefore occurs on February 28
/// during non-leap years and returns to February 29 in later leap years.
///
/// ## Termination
///
/// [end] may contain calendar-date, occurrence-count, cumulative-amount
/// conditions, or a combination.
///
/// This class can enforce only date and count conditions because those values
/// depend exclusively on calendar recurrence state.
///
/// Amount termination depends on cumulative monetary progress and is evaluated
/// separately by the occurrence-generation workflow.
///
/// Consequently, an amount-only recurrence still produces an unbounded
/// calendar sequence through [occurrenceAt]; generation stops once its amount
/// target is reached.
///
/// ## Invariants
///
/// - [interval] is at least one.
/// - [end.until], when supplied, cannot precede [startsOn].
@MappableClass()
final class RecurrenceRule with RecurrenceRuleMappable {
  /// First scheduled occurrence date.
  final CalendarDate startsOn;

  /// Calendar unit in which the recurrence advances.
  final RecurrenceFrequency frequency;

  /// Number of [frequency] units between consecutive scheduled occurrences.
  final int interval;

  /// Optional recurrence termination conditions.
  final RecurrenceEnd? end;

  /// Creates a recurrence rule.
  ///
  /// Throws an [ArgumentError] when:
  ///
  /// - [interval] is less than one; or
  /// - an inclusive recurrence end date precedes [startsOn].
  @MappableConstructor()
  RecurrenceRule({
    required this.startsOn,
    required this.frequency,
    this.interval = 1,
    this.end,
  }) {
    if (interval < 1) {
      throw ArgumentError.value(
        interval,
        'interval',
        'Recurrence interval must be at least one.',
      );
    }

    final endDate = end?.until;

    if (endDate != null && endDate.isBefore(startsOn)) {
      throw ArgumentError.value(
        endDate,
        'end',
        'Recurrence end date cannot precede the start date.',
      );
    }
  }

  /// Returns the scheduled occurrence at zero-based [index].
  ///
  /// Returns `null` when [index] exceeds a configured date or count boundary.
  ///
  /// An amount-based termination condition is deliberately not evaluated here.
  /// The caller must evaluate cumulative amount progress separately.
  ///
  /// Throws a [RangeError] when [index] is negative.
  CalendarDate? occurrenceAt(int index) {
    if (index < 0) {
      throw RangeError.range(
        index,
        0,
        null,
        'index',
        'Occurrence index cannot be negative.',
      );
    }

    final candidate = _candidateAt(index);

    if (end != null && !end!.allows(date: candidate, occurrenceIndex: index)) {
      return null;
    }

    return candidate;
  }

  /// Whether [date] is a scheduled calendar occurrence.
  ///
  /// Amount-based termination is deliberately ignored because this method has
  /// no cumulative financial context.
  bool occursOn(CalendarDate date) {
    if (date.isBefore(startsOn)) {
      return false;
    }

    final index = _firstIndexOnOrAfter(date);
    final candidate = occurrenceAt(index);

    return candidate != null && candidate.compareTo(date) == 0;
  }

  /// Returns the first scheduled occurrence on or after [date].
  ///
  /// Returns `null` when a date or count end condition prevents another
  /// occurrence.
  ///
  /// Amount-based termination is deliberately not evaluated.
  CalendarDate? nextOnOrAfter(CalendarDate date) {
    final index = _firstIndexOnOrAfter(date);
    return occurrenceAt(index);
  }

  /// Returns scheduled occurrences inside the half-open range `[from, until)`.
  ///
  /// Date and count termination conditions are honored.
  ///
  /// Amount termination is deliberately not evaluated because this operation
  /// has no cumulative monetary progress.
  ///
  /// The returned collection is immutable.
  ///
  /// Throws an [ArgumentError] when [until] is not after [from].
  List<CalendarDate> occurrencesBetween({
    required CalendarDate from,
    required CalendarDate until,
  }) {
    if (!until.isAfter(from)) {
      throw ArgumentError.value(
        until,
        'until',
        'Occurrence range end must be after its start.',
      );
    }

    final occurrences = <CalendarDate>[];
    var index = _firstIndexOnOrAfter(from);

    while (true) {
      final occurrence = occurrenceAt(index);

      if (occurrence == null || !occurrence.isBefore(until)) {
        break;
      }

      occurrences.add(occurrence);
      index++;
    }

    return List.unmodifiable(occurrences);
  }

  CalendarDate _candidateAt(int index) {
    return switch (frequency) {
      RecurrenceFrequency.daily => _dailyCandidate(index),
      RecurrenceFrequency.weekly => _weeklyCandidate(index),
      RecurrenceFrequency.monthly => _monthlyCandidate(index),
      RecurrenceFrequency.yearly => _yearlyCandidate(index),
    };
  }

  CalendarDate _dailyCandidate(int index) {
    final date = startsOn.toDateTimeUtc().add(Duration(days: interval * index));

    return CalendarDate.fromDateTime(date);
  }

  CalendarDate _weeklyCandidate(int index) {
    final date = startsOn.toDateTimeUtc().add(
      Duration(days: 7 * interval * index),
    );

    return CalendarDate.fromDateTime(date);
  }

  CalendarDate _monthlyCandidate(int index) {
    final startMonthIndex = startsOn.year * 12 + startsOn.month - 1;
    final targetMonthIndex = startMonthIndex + interval * index;

    final year = targetMonthIndex ~/ 12;
    final month = targetMonthIndex % 12 + 1;
    final lastDay = _lastDayOfMonth(year, month);

    final day = startsOn.day <= lastDay ? startsOn.day : lastDay;

    return CalendarDate(year, month, day);
  }

  CalendarDate _yearlyCandidate(int index) {
    final year = startsOn.year + interval * index;
    final lastDay = _lastDayOfMonth(year, startsOn.month);

    final day = startsOn.day <= lastDay ? startsOn.day : lastDay;

    return CalendarDate(year, startsOn.month, day);
  }

  int _firstIndexOnOrAfter(CalendarDate date) {
    if (date.isOnOrBefore(startsOn)) {
      return 0;
    }

    final approximateIndex = switch (frequency) {
      RecurrenceFrequency.daily => _approximateDayIndex(
        date,
        daysPerInterval: interval,
      ),
      RecurrenceFrequency.weekly => _approximateDayIndex(
        date,
        daysPerInterval: 7 * interval,
      ),
      RecurrenceFrequency.monthly => _approximateMonthIndex(date),
      RecurrenceFrequency.yearly => _approximateYearIndex(date),
    };

    final candidate = _candidateAt(approximateIndex);

    return candidate.isBefore(date) ? approximateIndex + 1 : approximateIndex;
  }

  int _approximateDayIndex(CalendarDate date, {required int daysPerInterval}) {
    final dayDifference = date
        .toDateTimeUtc()
        .difference(startsOn.toDateTimeUtc())
        .inDays;

    return dayDifference ~/ daysPerInterval;
  }

  int _approximateMonthIndex(CalendarDate date) {
    final monthDifference =
        (date.year - startsOn.year) * 12 + date.month - startsOn.month;

    return monthDifference ~/ interval;
  }

  int _approximateYearIndex(CalendarDate date) {
    final yearDifference = date.year - startsOn.year;

    return yearDifference ~/ interval;
  }

  static int _lastDayOfMonth(int year, int month) {
    return DateTime.utc(year, month + 1, 0).day;
  }
}
