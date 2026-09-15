import 'package:axiom/src/core/result/result.dart';
import 'package:dart_mappable/dart_mappable.dart';

import 'persistence_failure.dart';

part 'database_open_failure.mapper.dart';

/// Indicates that the database could not be opened for use by the application.
///
/// This may result from an inaccessible database path, a storage-provider
/// error, an unsupported database format, or a failure while initializing the
/// database schema. No database instance is available to callers when this
/// failure is returned.
@MappableClass()
final class DatabaseOpenFailure extends Failure<DatabaseOpenFailure>
    with DatabaseOpenFailureMappable
    implements PersistenceFailure {
  /// Creates a database-open failure with an optional explanation.
  const DatabaseOpenFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'persistence.database_open';

  @override
  DatabaseOpenFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
