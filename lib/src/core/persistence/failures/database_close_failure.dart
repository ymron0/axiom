import 'package:axiom/src/core/result/result.dart';
import 'package:dart_mappable/dart_mappable.dart';

import 'persistence_failure.dart';

part 'database_close_failure.mapper.dart';

/// Indicates that an open database could not be closed cleanly.
///
/// The database resource may still be held by the persistence layer after this
/// failure. Callers should not assume that pending writes have been flushed or
/// that the database can be safely reopened until the close operation has been
/// resolved.
@MappableClass()
final class DatabaseCloseFailure extends Failure<DatabaseCloseFailure>
    with DatabaseCloseFailureMappable
    implements PersistenceFailure {
  /// Creates a database-close failure with an optional explanation.
  const DatabaseCloseFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'persistence.database_close';

  @override
  DatabaseCloseFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
