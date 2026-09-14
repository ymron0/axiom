/// Defines the persistent database schema metadata.
///
/// The schema version must be incremented whenever an existing persisted
/// database requires a migration.
///
/// Store creation is not performed here because Sembast creates stores
/// lazily when records are written.
abstract final class DatabaseSchema {
  /// Current database schema version.
  static const int version = 1;

  /// File name used for the application's Sembast database.
  static const String fileName = 'app.db';
}
