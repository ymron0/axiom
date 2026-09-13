import 'package:dart_mappable/dart_mappable.dart';

part 'calendar_date.mapper.dart';

/// Represents a calendar date without a time or timezone.
///
/// Use this value object when the domain cares about a day rather than a
/// specific instant in time.
///
/// Examples include:
///
/// - budget effective dates;
/// - statement dates;
/// - recurrence dates;
/// - other date-only business rules.
@MappableClass()
final class CalendarDate
    with CalendarDateMappable
    implements Comparable<CalendarDate> {
  /// Calendar year.
  final int year;

  /// Calendar month from 1 through 12.
  final int month;

  /// Calendar day within [month].
  final int day;

  /// Creates a calendar date.
  ///
  /// Throws an [ArgumentError] when the supplied year, month, and day do not
  /// form a valid calendar date.
  @MappableConstructor()
  CalendarDate(this.year, this.month, this.day) {
    final date = DateTime.utc(year, month, day);

    if (date.year != year || date.month != month || date.day != day) {
      throw ArgumentError.value(
        '$year-$month-$day',
        'date',
        'Invalid calendar date.',
      );
    }
  }

  /// Creates a calendar date from [date], discarding its time component.
  factory CalendarDate.fromDateTime(DateTime date) {
    return CalendarDate(date.year, date.month, date.day);
  }

  /// Converts this value to a UTC [DateTime] at midnight.
  DateTime toDateTimeUtc() => DateTime.utc(year, month, day);

  /// Whether this date occurs before [other].
  bool isBefore(CalendarDate other) => compareTo(other) < 0;

  /// Whether this date occurs after [other].
  bool isAfter(CalendarDate other) => compareTo(other) > 0;

  /// Whether this date is the same as or before [other].
  bool isOnOrBefore(CalendarDate other) => compareTo(other) <= 0;

  /// Whether this date is the same as or after [other].
  bool isOnOrAfter(CalendarDate other) => compareTo(other) >= 0;

  @override
  int compareTo(CalendarDate other) {
    final yearComparison = year.compareTo(other.year);
    if (yearComparison != 0) {
      return yearComparison;
    }

    final monthComparison = month.compareTo(other.month);
    if (monthComparison != 0) {
      return monthComparison;
    }

    return day.compareTo(other.day);
  }

  @override
  String toString() {
    final paddedMonth = month.toString().padLeft(2, '0');
    final paddedDay = day.toString().padLeft(2, '0');

    return '$year-$paddedMonth-$paddedDay';
  }
}
