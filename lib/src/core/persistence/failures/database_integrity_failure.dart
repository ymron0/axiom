import 'package:axiom/src/core/result/result.dart';
import 'package:dart_mappable/dart_mappable.dart';

import 'persistence_failure.dart';

part 'database_integrity_failure.mapper.dart';

/// Indicates that persisted database data failed an integrity check.
///
/// The database may be structurally readable but contain inconsistent,
/// incomplete, or otherwise unsafe data. Callers must treat it as unusable
/// until the integrity problem has been resolved or recovery has succeeded.
@MappableClass()
final class DatabaseIntegrityFailure
    extends Failure<DatabaseIntegrityFailure>
    with DatabaseIntegrityFailureMappable
    implements PersistenceFailure {
  /// Creates a database-integrity failure with an optional explanation.
  const DatabaseIntegrityFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'persistence.database_integrity';

  @override
  DatabaseIntegrityFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
