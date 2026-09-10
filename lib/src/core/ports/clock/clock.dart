// coverage:ignore-file

/// Provides date and time values to application workflows.
///
/// Depend on this interface when time must be replaceable for testing or other
/// runtime environments.
///
/// ## Invariants
///
/// Implementations return the current local-time value from [now] and the
/// corresponding value expressed in UTC from [nowUtc]. Implementations that
/// use a fixed time source return deterministic values from both getters.
///
/// ## Semantics
///
/// [Clock] abstracts the source of current time. Production implementations
/// can use the system clock, while tests and other runtime environments can
/// provide a deterministic time source.
///
/// ## Contract
///
/// Callers should depend on this interface instead of reading
/// `DateTime.now()` directly. The local and UTC getters represent the same
/// clock source, with [nowUtc] expressed in UTC.
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
