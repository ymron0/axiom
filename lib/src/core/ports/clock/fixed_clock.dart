import 'package:axiom/src/core/ports/clock/clock.dart';

/// A [Clock] that returns one immutable instant.
///
/// The fixed instant is returned on every read. No time elapses automatically,
/// and [nowUtc] returns the same instant expressed in UTC.
///
/// ## Invariants
///
/// The supplied instant is immutable, repeated reads are deterministic, and
/// the clock does not advance automatically. [nowUtc] corresponds to [now]
/// converted to UTC.
///
/// ## Semantics
///
/// Use [FixedClock] for deterministic tests and debug execution when workflows
/// must observe a stable point in time.
///
/// ## Contract
///
/// Construct the clock with the instant callers want the workflow to observe.
/// The supplied local or UTC representation is preserved by [now], while
/// [nowUtc] always returns a UTC representation of that same instant.
///
/// ```dart
/// const clock = FixedClock(DateTime.utc(2026, 9, 10));
/// final DateTime timestamp = clock.nowUtc;
/// ```
final class FixedClock implements Clock {
  /// Creates a clock fixed at [instant].
  const FixedClock(this._instant);

  final DateTime _instant;

  /// The supplied fixed instant in its original local or UTC representation.
  @override
  DateTime get now => _instant;

  /// The supplied fixed instant expressed in UTC.
  @override
  DateTime get nowUtc => _instant.toUtc();
}
