import 'package:axiom/src/core/ports/clock/clock.dart';
import 'package:axiom/src/core/ports/clock/fixed_clock.dart';
import 'package:axiom/src/core/ports/clock/system_clock.dart';

/// Creates the application's clock from the compile-time `DEBUG_NOW` value.
///
/// When `DEBUG_NOW` is empty, returns a [SystemClock]. When it contains an
/// ISO-8601 timestamp accepted by [DateTime.parse], returns a [FixedClock] for
/// that instant. Values without a timezone are interpreted as local time;
/// values with `Z` or an offset preserve their represented instant.
/// Invalid non-empty values throw [FormatException].
///
/// Configure a deterministic instant with:
///
/// ```text
/// --dart-define=DEBUG_NOW=2026-01-01T08:05:00Z
/// ```
Clock createClock() {
  const debugNow = String.fromEnvironment('DEBUG_NOW');

  if (debugNow.isEmpty) {
    return const SystemClock();
  }

  return FixedClock(DateTime.parse(debugNow));
}
