// coverage:ignore-file

/// Defines persistent database schema metadata.
///
/// Schema versions begin at 1.
///
/// Increment [version] only when an existing persisted database requires a
/// defined schema transition.
///
/// Every increment after version 1 must have a corresponding immutable
/// `DatabaseMigration` registered in `DatabaseMigrations`.
///
/// Store creation is not performed here because Sembast creates stores lazily
/// when records are written.
abstract final class DatabaseSchema {
  /// Current released database schema version.
  ///
  /// Keep this at 1 until the first real persisted-schema change is introduced.
  static const int version = 1;

  /// File name used for the application's Sembast database.
  static const String fileName = 'app.db';
}
