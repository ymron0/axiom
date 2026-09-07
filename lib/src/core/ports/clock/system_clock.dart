import 'package:axiom/src/core/ports/clock/clock.dart';

/// A [Clock] backed by the system clock.
///
/// A compile-time `DEBUG_NOW` value overrides the system time, allowing the
/// clock to return a fixed value during development.
///
/// ```dart
/// const Clock clock = SystemClock();
/// final DateTime timestamp = clock.now;
/// ```
final class SystemClock implements Clock {
  /// The compile-time `DEBUG_NOW` override, or an empty string when unset.
  ///
  /// Supply the value as an ISO-8601 date and time with
  /// `--dart-define=DEBUG_NOW=<value>`.
  static const debugNow = String.fromEnvironment('DEBUG_NOW');

  final String _debugNow;

  /// Creates a clock using [debugNow], or [SystemClock.debugNow] when omitted.
  ///
  /// An empty value uses the system time.
  const SystemClock({String? debugNow})
    : _debugNow = debugNow ?? SystemClock.debugNow;

  /// Returns [_debugNow] when configured; otherwise, returns the system time.
  ///
  /// Throws a [FormatException] when [_debugNow] is not a valid ISO-8601 date
  /// and time.
  @override
  DateTime get now {
    return _debugNow.isEmpty ? DateTime.now() : DateTime.parse(_debugNow);
  }

  /// Returns [now] converted to UTC.
  ///
  /// Throws a [FormatException] when [debugNow] is configured but is not a
  /// valid ISO-8601 date and time.
  @override
  DateTime get nowUtc {
    return now.toUtc();
  }
}
