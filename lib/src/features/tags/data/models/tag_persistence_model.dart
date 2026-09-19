import 'package:axiom/src/core/identity/ids/tag_id.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_exception.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_helpers.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_reader.dart';
import 'package:axiom/src/features/tags/domain/entities/tag.dart';

/// Persistence representation of one [Tag].
///
/// The Sembast record key contains the tag identifier and is therefore not
/// duplicated inside [toRecord].
///
/// Tag lifecycle state is represented explicitly so deleted caller-owned
/// snapshots can be converted through this model even though deleted tags are
/// never retained by [SembastTagRepositoryImpl].
///
/// Persisted data is treated as untrusted. Structural persistence validation is
/// performed while reading the record, and current domain invariants are
/// re-applied by [toEntity].
final class TagPersistenceModel {
  /// Persisted field containing the normalized tag display name.
  static const String nameField = 'name';

  /// Persisted field containing the archive timestamp.
  static const String archivedAtField = 'archivedAt';

  /// Persisted field containing the deletion timestamp.
  ///
  /// Normal repository records contain `null` because tag deletion is
  /// physical.
  static const String deletedAtField = 'deletedAt';

  static const String _createdAtField = 'createdAt';
  static const String _modifiedAtField = 'modifiedAt';
  static const String _entityVersionField = 'entityVersion';

  /// Serialized tag identity.
  final String id;

  /// Normalized tag display name.
  final String name;

  /// UTC creation timestamp.
  final DateTime createdAt;

  /// UTC last-modification timestamp.
  final DateTime modifiedAt;

  /// UTC archive timestamp, when archived.
  final DateTime? archivedAt;

  /// UTC deletion timestamp, when represented by a deleted snapshot.
  final DateTime? deletedAt;

  /// Aggregate class version.
  final int entityVersion;

  /// Creates a tag persistence model.
  const TagPersistenceModel({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.modifiedAt,
    required this.archivedAt,
    required this.deletedAt,
    required this.entityVersion,
  });

  /// Creates a persistence model from [tag].
  factory TagPersistenceModel.fromEntity(Tag tag) {
    return TagPersistenceModel(
      id: tag.id.value,
      name: tag.name,
      createdAt: tag.createdAt.toUtc(),
      modifiedAt: tag.modifiedAt.toUtc(),
      archivedAt: tag.archivedAt?.toUtc(),
      deletedAt: tag.deletedAt?.toUtc(),
      entityVersion: tag.entityVersion,
    );
  }

  /// Reconstructs a persistence model from [record].
  ///
  /// [recordKey] contains the serialized [TagId].
  factory TagPersistenceModel.fromRecord({
    required String recordKey,
    required PersistenceRecord record,
  }) {
    final reader = PersistenceRecordReader(record);

    return TagPersistenceModel(
      id: recordKey,
      name: reader.requiredString(nameField),
      createdAt: readPersistenceDateTime(reader, _createdAtField),
      modifiedAt: readPersistenceDateTime(reader, _modifiedAtField),
      archivedAt: readOptionalUtcDateTime(reader, archivedAtField),
      deletedAt: readOptionalUtcDateTime(reader, deletedAtField),
      entityVersion: readPositivePersistenceInt(reader, _entityVersionField),
    );
  }

  /// Reconstructs the domain tag represented by this model.
  ///
  /// Current tag invariants are deliberately re-applied during reconstruction.
  Tag toEntity() {
    try {
      return Tag(
        id: TagId.fromString(id),
        name: name,
        createdAt: createdAt,
        modifiedAt: modifiedAt,
        archivedAt: archivedAt,
        deletedAt: deletedAt,
        entityVersion: entityVersion,
      );
    } on ArgumentError {
      throw const PersistenceRecordException(
        reason: 'Persisted tag violates current domain invariants.',
      );
    }
  }

  /// Converts this model to the primitive Sembast representation.
  PersistenceRecord toRecord() {
    return <String, Object?>{
      nameField: name,
      _createdAtField: createdAt.toUtc().toIso8601String(),
      _modifiedAtField: modifiedAt.toUtc().toIso8601String(),
      archivedAtField: archivedAt?.toUtc().toIso8601String(),
      deletedAtField: deletedAt?.toUtc().toIso8601String(),
      _entityVersionField: entityVersion,
    };
  }
}
