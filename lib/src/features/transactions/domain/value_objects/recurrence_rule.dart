import 'package:axiom/src/core/domain/value_objects/calendar_date.dart';
import 'package:axiom/src/features/transactions/domain/enums/recurrence_frequency.dart';
import 'package:axiom/src/features/transactions/domain/value_objects/recurrence_end.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'recurrence_rule.mapper.dart';

/// Defines the calendar recurrence of a transaction series.
@MappableClass()
final class RecurrenceRule with RecurrenceRuleMappable {
  /// First scheduled occurrence date.
  final CalendarDate startsOn;

  /// Calendar unit in which the recurrence advances.
  final RecurrenceFrequency frequency;

  /// Number of frequency units between occurrences.
  final int interval;

  /// Optional termination conditions.
  final RecurrenceEnd? end;

  /// Creates a recurrence rule.
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

  /// Returns the occurrence at zero-based [index].
  ///
  /// [additionalOccurrences] extends configured count/date recurrence
  /// boundaries by that many recurrence slots.
  ///
  /// It is used for skipped occurrences that explicitly request compensation at
  /// the end of the series.
  CalendarDate? occurrenceAt(int index, {int additionalOccurrences = 0}) {
    if (index < 0) {
      throw RangeError.range(
        index,
        0,
        null,
        'index',
        'Occurrence index cannot be negative.',
      );
    }

    if (additionalOccurrences < 0) {
      throw RangeError.range(
        additionalOccurrences,
        0,
        null,
        'additionalOccurrences',
        'Additional occurrences cannot be negative.',
      );
    }

    final candidate = _candidateAt(index);
    final configuredEnd = end;

    if (configuredEnd == null) {
      return candidate;
    }

    final count = configuredEnd.count;

    if (count != null && index >= count + additionalOccurrences) {
      return null;
    }

    final until = configuredEnd.until;

    if (until != null) {
      final lastOriginalIndex = _lastIndexOnOrBefore(until);

      if (index > lastOriginalIndex + additionalOccurrences) {
        return null;
      }
    }

    return candidate;
  }

  /// Whether [date] is a scheduled calendar occurrence.
  bool occursOn(CalendarDate date, {int additionalOccurrences = 0}) {
    if (date.isBefore(startsOn)) {
      return false;
    }

    final index = _firstIndexOnOrAfter(date);

    final candidate = occurrenceAt(
      index,
      additionalOccurrences: additionalOccurrences,
    );

    return candidate != null && candidate.compareTo(date) == 0;
  }

  /// Returns the first occurrence on or after [date].
  CalendarDate? nextOnOrAfter(CalendarDate date) {
    final index = _firstIndexOnOrAfter(date);
    return occurrenceAt(index);
  }

  /// Returns scheduled occurrences inside `[from, until)`.
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

  int _lastIndexOnOrBefore(CalendarDate date) {
    final firstOnOrAfter = _firstIndexOnOrAfter(date);
    final candidate = _candidateAt(firstOnOrAfter);

    if (candidate.isOnOrBefore(date)) {
      return firstOnOrAfter;
    }

    return firstOnOrAfter - 1;
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
