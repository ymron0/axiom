import 'package:axiom/src/core/identity/ids/tag_id.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_exception.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_helpers.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_reader.dart';
import 'package:axiom/src/features/tags/domain/entities/tag.dart';
import 'package:axiom/src/features/tags/domain/validation/tag_name_normalization.dart';

/// Persistence representation of one [Tag].
///
/// The tag ID is represented by the Sembast record key.
///
/// [nameKey] is a normalized, case-insensitive lookup key derived from [name].
/// It is persisted separately so name equality queries do not need to
/// repeatedly normalize every current record.
///
/// Records written before [nameKey] was introduced remain readable. When the
/// field is absent it is reconstructed from [name]. A present but inconsistent
/// value is treated as persistence corruption.
final class TagPersistenceModel {
  /// Persisted normalized display name.
  static const String nameField = 'name';

  /// Persisted normalized comparison key used by name lookup.
  static const String nameKeyField = 'nameKey';

  /// Persisted archive timestamp.
  static const String archivedAtField = 'archivedAt';

  /// Persisted deletion timestamp.
  static const String deletedAtField = 'deletedAt';

  static const String _createdAtField = 'createdAt';
  static const String _modifiedAtField = 'modifiedAt';
  static const String _entityVersionField = 'entityVersion';

  /// Serialized tag identity.
  final String id;

  /// Normalized display name.
  final String name;

  /// Canonical case-insensitive name comparison key.
  final String nameKey;

  /// UTC creation timestamp.
  final DateTime createdAt;

  /// UTC modification timestamp.
  final DateTime modifiedAt;

  /// UTC archive timestamp.
  final DateTime? archivedAt;

  /// UTC deletion timestamp.
  final DateTime? deletedAt;

  /// Domain entity version.
  final int entityVersion;

  /// Creates a tag persistence model.
  const TagPersistenceModel({
    required this.id,
    required this.name,
    required this.nameKey,
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
      nameKey: tagNameKey(tag.name),
      createdAt: tag.createdAt.toUtc(),
      modifiedAt: tag.modifiedAt.toUtc(),
      archivedAt: tag.archivedAt?.toUtc(),
      deletedAt: tag.deletedAt?.toUtc(),
      entityVersion: tag.entityVersion,
    );
  }

  /// Reconstructs a persistence model from [record].
  ///
  /// Legacy records without [nameKeyField] are accepted and have the key
  /// derived from [nameField].
  ///
  /// A stored [nameKeyField] that disagrees with the derived key is rejected as
  /// corrupted persisted data.
  factory TagPersistenceModel.fromRecord({
    required String recordKey,
    required PersistenceRecord record,
  }) {
    final reader = PersistenceRecordReader(record);
    final name = reader.requiredString(nameField);

    final String derivedNameKey;

    try {
      derivedNameKey = tagNameKey(name);
    } on ArgumentError {
      throw const PersistenceRecordException(
        field: nameField,
        reason: 'Persisted tag name is invalid.',
      );
    }

    if (reader.contains(nameKeyField)) {
      final persistedNameKey = reader.requiredString(nameKeyField);

      if (persistedNameKey != derivedNameKey) {
        throw const PersistenceRecordException(
          field: nameKeyField,
          reason:
              'Persisted tag name index does not match the canonical tag name.',
        );
      }
    }

    return TagPersistenceModel(
      id: recordKey,
      name: name,
      nameKey: derivedNameKey,
      createdAt: readPersistenceDateTime(reader, _createdAtField),
      modifiedAt: readPersistenceDateTime(reader, _modifiedAtField),
      archivedAt: readOptionalUtcDateTime(reader, archivedAtField),
      deletedAt: readOptionalUtcDateTime(reader, deletedAtField),
      entityVersion: readPositivePersistenceInt(reader, _entityVersionField),
    );
  }

  /// Reconstructs the domain tag.
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

  /// Converts this model into a Sembast-compatible record.
  PersistenceRecord toRecord() {
    return <String, Object?>{
      nameField: name,
      nameKeyField: nameKey,
      _createdAtField: createdAt.toUtc().toIso8601String(),
      _modifiedAtField: modifiedAt.toUtc().toIso8601String(),
      archivedAtField: archivedAt?.toUtc().toIso8601String(),
      deletedAtField: deletedAt?.toUtc().toIso8601String(),
      _entityVersionField: entityVersion,
    };
  }
}
