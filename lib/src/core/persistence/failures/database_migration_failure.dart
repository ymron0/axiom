import 'package:axiom/src/core/result/result.dart';
import 'package:dart_mappable/dart_mappable.dart';

import 'persistence_failure.dart';

part 'database_migration_failure.mapper.dart';

/// Indicates that persisted data could not be migrated to the required schema.
///
/// The database must not be exposed to repositories after this failure.
///
/// Because migrations execute atomically, a failed migration must leave the
/// previously persisted schema unchanged and eligible for a later safe retry.
@MappableClass()
final class DatabaseMigrationFailure extends Failure<DatabaseMigrationFailure>
    with DatabaseMigrationFailureMappable
    implements PersistenceFailure {
  /// Schema version from which migration was attempted.
  final int fromVersion;

  /// Schema version to which migration was attempted.
  final int toVersion;

  /// Creates a database migration failure.
  const DatabaseMigrationFailure({
    required this.fromVersion,
    required this.toVersion,
    String? message,
  }) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'persistence.database_migration';

  @override
  DatabaseMigrationFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
