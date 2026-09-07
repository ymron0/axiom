// coverage:ignore-file

/// Provides date and time values to application workflows.
///
/// Depend on this interface when time must be replaceable for testing or other
/// runtime environments.
///
/// ```dart
/// final Clock clock = SystemClock();
/// final DateTime timestamp = clock.nowUtc;
/// ```
abstract interface class Clock {
  /// The current date and time in the clock's native time zone.
  DateTime get now;

  /// The current date and time in UTC.
  DateTime get nowUtc;
}
