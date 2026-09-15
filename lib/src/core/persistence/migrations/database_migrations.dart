import 'database_migration.dart';

/// Declares the complete released database migration history.
///
/// This registry is append-only.
///
/// Every time `DatabaseSchema.version` is incremented, exactly one migration
/// must be appended for the transition from the previous schema version to the
/// new schema version.
///
/// Existing migrations must never be reordered, modified, or removed after
/// release because users may upgrade directly from any previously released
/// database version.
///
/// Schema version 1 is the baseline schema, so there are currently no upgrade
/// migrations.
abstract final class DatabaseMigrations {
  /// Complete migration history in ascending version order.
  static final List<DatabaseMigration> all =
      List<DatabaseMigration>.unmodifiable(<DatabaseMigration>[
        // No upgrade migrations exist while DatabaseSchema.version == 1.
      ]);
}
