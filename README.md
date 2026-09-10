# axiom

A Flutter budget tracker and personal-finance aggregator built with Clean Architecture and Domain-Driven Design.

## Flutter upgrades

When upgrading Flutter, also update the version pinned in the `Set up Flutter` step of [`.github/workflows/coverage.yml`](.github/workflows/coverage.yml).

## Clock

The application uses a [`Clock`](lib/src/core/ports/clock.dart) port instead of calling `DateTime.now()` directly.

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

Use `SystemClock` to access the current time:

```dart
final clock = SystemClock();
final now = clock.now;
final nowUtc = clock.nowUtc;
```

### Debug time override

In debug mode, set the `DEBUG_NOW` compile-time environment variable to fix the clock at a specific local date and time.

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
dart run --define=DEBUG_NOW=2026-01-01T08:05:00 path/to/script.dart
```

If `DEBUG_NOW` is not set, `SystemClock` uses the current system time.
