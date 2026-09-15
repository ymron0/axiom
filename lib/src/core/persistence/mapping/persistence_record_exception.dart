/// Internal exception thrown when a persisted record does not have the
/// structure expected by a persistence mapper.
///
/// This exception belongs entirely to the persistence infrastructure and must
/// not escape into application or domain code.
///
/// [VersionedPersistenceMapper] translates it into an appropriate typed
/// [PersistenceFailure].
final class PersistenceRecordException implements Exception {
  const PersistenceRecordException({required this.reason, this.field});

  /// The field responsible for the failure, when the failure is associated
  /// with a specific field.
  final String? field;

  /// Human-readable description of why the persisted value is invalid.
  ///
  /// This should describe the structural problem without including persisted
  /// user data.
  final String reason;

  @override
  String toString() {
    final field = this.field;

    if (field == null) {
      return 'PersistenceRecordException: $reason';
    }

    return 'PersistenceRecordException($field): $reason';
  }
}
