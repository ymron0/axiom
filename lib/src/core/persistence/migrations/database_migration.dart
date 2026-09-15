import 'package:axiom/src/core/persistence/migrations/database_migration_operation.dart';

/// Describes one adjacent persistent database schema transition.
///
/// A migration always represents exactly one released schema transition:
///
/// `fromVersion -> toVersion`
///
/// For example:
///
/// `1 -> 2`
///
/// Database migrations are append-only release history. Once a migration has
/// shipped, its version numbers and behavior must not be changed.
///
/// [DatabaseMigrator] validates that registered migrations are contiguous and
/// that [toVersion] is exactly [fromVersion] + 1.
final class DatabaseMigration {
  /// Schema version expected before this migration runs.
  final int fromVersion;

  /// Schema version represented after this migration succeeds.
  final int toVersion;

  /// Operation that transforms persisted data for this transition.
  final DatabaseMigrationOperation operation;

  /// Creates one database migration definition.
  const DatabaseMigration({
    required this.fromVersion,
    required this.toVersion,
    required this.operation,
  });
}
