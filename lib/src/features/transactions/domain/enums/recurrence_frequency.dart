// coverage:ignore-file

import 'package:dart_mappable/dart_mappable.dart';

part 'recurrence_frequency.mapper.dart';

/// Defines the calendar unit used by a recurring transaction series.
///
/// Frequency alone does not determine a complete recurrence. The owning
/// `RecurrenceRule` also defines the start date, interval, and optional end
/// conditions.
///
/// Recurrence is calendar based rather than instant based. Conversion from an
/// occurrence date to a transaction's effective instant belongs to the
/// occurrence-generation workflow.
@MappableEnum()
enum RecurrenceFrequency {
  /// Repeats every configured number of calendar days.
  daily,

  /// Repeats every configured number of seven-day calendar periods.
  weekly,

  /// Repeats every configured number of calendar months.
  monthly,

  /// Repeats every configured number of calendar years.
  yearly,
}
