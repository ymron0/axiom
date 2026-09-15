import 'package:axiom/src/core/result/result.dart';
import 'package:dart_mappable/dart_mappable.dart';

import 'persistence_failure.dart';

part 'database_version_failure.mapper.dart';

/// Indicates that the database schema version cannot be handled safely.
///
/// This occurs when a persisted database reports an invalid version or a
/// version newer than the migrations supported by the application. The
/// database must not be used until the version is understood or remediated.
@MappableClass()
final class DatabaseVersionFailure
    extends Failure<DatabaseVersionFailure>
    with DatabaseVersionFailureMappable
    implements PersistenceFailure {
  /// Creates a database-version failure with an optional explanation.
  const DatabaseVersionFailure({
    String? message,
    this.existingVersion,
    this.supportedVersion,
  }) : super(message);

  /// Schema version found in the persisted database.
  final int? existingVersion;

  /// Highest schema version supported by the running application.
  final int? supportedVersion;

  /// Stable identifier for this failure kind.
  static const typeId = 'persistence.database_version';

  @override
  DatabaseVersionFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
