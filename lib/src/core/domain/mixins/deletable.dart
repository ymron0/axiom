/// Adds reversible deletion state to an entity.
///
/// Implementing classes provide a [deletedAt] timestamp. An entity is
/// considered deleted while that timestamp is set.
mixin Deletable {
  /// {@template deletable.deleted_at}
  /// The date and time when the entity was marked as deleted.
  ///
  /// A `null` value indicates that the entity is not deleted.
  /// {@endtemplate}
  DateTime? get deletedAt;

  /// Whether the entity is currently marked as deleted.
  bool get isDeleted => deletedAt != null;
}
