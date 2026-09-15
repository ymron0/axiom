/// Signals that a persisted database is newer than the schema version
/// supported by the running application.
///
/// This is an infrastructure exception rather than a user-facing failure.
/// It is thrown from the Sembast version-change callback because exceptions
/// are the mechanism by which that callback can abort opening.
///
/// [DatabaseLifecycleService] is responsible for translating this exception
/// into a typed `DatabaseVersionFailure`.
///
/// ## Invariants
///
/// [existingVersion] is the schema version found in persistence.
/// [supportedVersion] is the schema version requested by the application.
///
/// This exception is only expected when [existingVersion] is greater than
/// [supportedVersion].
final class UnsupportedDatabaseVersionException implements Exception {
  /// Schema version already stored in the database.
  final int existingVersion;

  /// Highest schema version supported by the running application.
  final int supportedVersion;

  /// Creates an unsupported-database-version exception.
  const UnsupportedDatabaseVersionException({
    required this.existingVersion,
    required this.supportedVersion,
  });
}
