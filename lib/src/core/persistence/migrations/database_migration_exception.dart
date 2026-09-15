/// Signals an expected failure while upgrading persisted database data.
///
/// This exception belongs entirely to persistence infrastructure.
///
/// It is thrown through Sembast's version-change callback so database opening
/// is aborted safely.
///
/// [DatabaseLifecycleService] translates this exception into a typed
/// `DatabaseMigrationFailure`.
///
/// Messages must describe the migration problem without including persisted
/// user data.
final class DatabaseMigrationException implements Exception {
  /// Schema version from which migration was attempted.
  final int fromVersion;

  /// Schema version to which migration was attempted.
  final int toVersion;

  /// Diagnostic explanation that does not contain persisted user data.
  final String message;

  /// Creates a database migration exception.
  const DatabaseMigrationException({
    required this.fromVersion,
    required this.toVersion,
    required this.message,
  });

  @override
  String toString() {
    return 'DatabaseMigrationException('
        '$fromVersion -> $toVersion'
        '): $message';
  }
}
