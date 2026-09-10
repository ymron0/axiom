# axiom

A Flutter budget tracker and personal-finance aggregator built with Clean Architecture and Domain-Driven Design.

## Flutter upgrades

When upgrading Flutter, also update the version pinned in the `Set up Flutter` step of [`.github/workflows/coverage.yml`](.github/workflows/coverage.yml).

## Clock

The application uses a [`Clock`](lib/src/core/ports/clock/clock.dart) port instead of calling `DateTime.now()` directly.

This makes time an explicit dependency that can be controlled in tests and during debugging.

### Clock port

The `Clock` interface exposes the current local and UTC time:

```dart
abstract interface class Clock {
  DateTime get now;
  DateTime get nowUtc;
}
```

### Usage

Use `createClock` as the application's clock creation point:

```dart
final clock = createClock();
final now = clock.now;
final nowUtc = clock.nowUtc;
```

`createClock` returns `SystemClock` when no debug override is configured. Tests
that need deterministic time can construct `FixedClock` directly with a
specific `DateTime`.

### Debug time override

Set the `DEBUG_NOW` compile-time environment variable to make `createClock`
return a `FixedClock` for a specific instant. Use an ISO-8601 timestamp. A
timestamp without a timezone is interpreted as local time; a timestamp with
`Z` or an explicit offset preserves that represented instant. Invalid
non-empty values throw `FormatException`.

For VS Code, configure [`.vscode/launch.json`](.vscode/launch.json) with:

```json
{
  "configurations": [
    {
      "toolArgs": [
        "--dart-define=DEBUG_NOW=2026-01-01T08:05:00"
      ]
    }
  ]
}
```

To provide the same value from the command line, run Flutter with:

```bash
flutter run --dart-define=DEBUG_NOW=2026-01-01T08:05:00
```

For a standalone Dart script, use:

```bash
dart run --define=DEBUG_NOW=2026-01-01T08:05:00Z path/to/script.dart
```

If `DEBUG_NOW` is not set, `createClock` returns a `SystemClock`, which reads
the current system time on every access. The selection is compile-time; there
is no runtime setting for changing the clock.
