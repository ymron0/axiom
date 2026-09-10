import 'package:axiom/src/core/ports/clock/clock.dart';

/// A [Clock] backed by the system clock.
///
/// Each getter reads the current host system clock without caching a timestamp.
/// [nowUtc] returns the current time expressed in UTC.
///
/// ```dart
/// const Clock clock = SystemClock();
/// final DateTime timestamp = clock.now;
/// ```
final class SystemClock implements Clock {
  /// Creates a clock backed by the host system clock.
  const SystemClock();

  /// The current system date and time locally.
  @override
  DateTime get now => DateTime.now();

  /// The current system date and time in UTC.
  @override
  DateTime get nowUtc => now.toUtc();
}
