/// Adds reversible archival state to an entity.
///
/// Implementing classes provide an [archivedAt] timestamp. An entity is
/// considered archived while that timestamp is set.
///
/// Archival is distinct from deletion. An archived entity remains persisted
/// and may continue to be referenced by historical domain records.
mixin Archivable {
  /// The date and time when the entity was archived.
  ///
  /// A `null` value indicates that the entity is not archived.
  DateTime? get archivedAt;

  /// Whether the entity is currently archived.
  bool get isArchived => archivedAt != null;
}
