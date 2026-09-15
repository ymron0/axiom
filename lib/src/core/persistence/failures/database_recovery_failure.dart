import 'package:axiom/src/core/result/result.dart';
import 'package:dart_mappable/dart_mappable.dart';

import 'persistence_failure.dart';

part 'database_recovery_failure.mapper.dart';

/// Indicates that database recovery did not restore a usable database.
///
/// This failure represents an unsuccessful recovery attempt after another
/// persistence problem, such as an open, migration, or integrity failure. It
/// may require repair, replacement, or user-directed recovery of the database.
@MappableClass()
final class DatabaseRecoveryFailure extends Failure<DatabaseRecoveryFailure>
    with DatabaseRecoveryFailureMappable
    implements PersistenceFailure {
  /// Creates a database-recovery failure with an optional explanation.
  const DatabaseRecoveryFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'persistence.database_recovery';

  @override
  DatabaseRecoveryFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
