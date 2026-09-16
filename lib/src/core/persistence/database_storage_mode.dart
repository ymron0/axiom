// coverage:ignore-file

/// Defines how the application stores its Sembast database.
enum DatabaseStorageMode {
  /// Stores the database in a physical file.
  persistent,

  /// Stores the database only in memory.
  memory,
}
