import 'package:axiom/src/core/identity/ids/merchant_id.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_exception.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_reader.dart';
import 'package:axiom/src/features/merchants/domain/entities/merchant.dart';

/// Persistence representation of a [Merchant].
///
/// This type owns translation between the merchant domain entity and the
/// storage-independent [PersistenceRecord] representation consumed by
/// Sembast repositories.
///
/// The merchant identifier is represented by the Sembast record key and is
/// therefore intentionally omitted from [toRecord].
///
/// Persisted timestamps are canonicalized to UTC ISO-8601 strings.
///
/// Persisted records are treated as untrusted input. Structural validation is
/// delegated to [PersistenceRecordReader], while current domain invariants are
/// revalidated when [toEntity] reconstructs the domain entity.
final class MerchantPersistenceModel {
  /// Persisted field containing the merchant name.
  static const String nameField = 'name';

  /// Persisted field containing the archive timestamp.
  static const String archivedAtField = 'archivedAt';

  /// Persisted field containing the deletion timestamp.
  ///
  /// Normal merchant repository records must always contain `null` here
  /// because merchant deletion is physical. The field nevertheless belongs to
  /// the persistence model so the model represents the complete domain
  /// snapshot and malformed persisted deleted records can be detected.
  static const String deletedAtField = 'deletedAt';

  static const String _createdAtField = 'createdAt';
  static const String _modifiedAtField = 'modifiedAt';
  static const String _entityVersionField = 'entityVersion';

  /// Serialized merchant identifier.
  ///
  /// This value is stored as the Sembast record key rather than inside the
  /// record map.
  final String id;

  /// Canonical merchant display name.
  final String name;

  /// Creation timestamp.
  final DateTime createdAt;

  /// Last modification timestamp.
  final DateTime modifiedAt;

  /// Archive timestamp, when archived.
  final DateTime? archivedAt;

  /// Deletion timestamp, when represented by a deleted snapshot.
  final DateTime? deletedAt;

  /// Domain entity version.
  final int entityVersion;

  /// Creates a merchant persistence model.
  const MerchantPersistenceModel({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.modifiedAt,
    required this.archivedAt,
    required this.deletedAt,
    required this.entityVersion,
  });

  /// Creates a persistence model from a valid domain [merchant].
  factory MerchantPersistenceModel.fromEntity(Merchant merchant) {
    return MerchantPersistenceModel(
      id: merchant.id.value,
      name: merchant.name,
      createdAt: merchant.createdAt.toUtc(),
      modifiedAt: merchant.modifiedAt.toUtc(),
      archivedAt: merchant.archivedAt?.toUtc(),
      deletedAt: merchant.deletedAt?.toUtc(),
      entityVersion: merchant.entityVersion,
    );
  }

  /// Reconstructs a persistence model from a persisted [record].
  ///
  /// [recordKey] is the serialized merchant identifier.
  ///
  /// Throws [PersistenceRecordException] when a required field is missing,
  /// has the wrong type, or contains an invalid timestamp.
  factory MerchantPersistenceModel.fromRecord({
    required String recordKey,
    required PersistenceRecord record,
  }) {
    final reader = PersistenceRecordReader(record);

    return MerchantPersistenceModel(
      id: recordKey,
      name: reader.requiredString(nameField),
      createdAt: _readUtcDateTime(reader, _createdAtField),
      modifiedAt: _readUtcDateTime(reader, _modifiedAtField),
      archivedAt: _readOptionalUtcDateTime(reader, archivedAtField),
      deletedAt: _readOptionalUtcDateTime(reader, deletedAtField),
      entityVersion: reader.requiredInt(_entityVersionField),
    );
  }

  /// Converts this model into its persisted record representation.
  ///
  /// The merchant identifier is deliberately excluded because it is used as
  /// the Sembast record key.
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

  /// Reconstructs the merchant domain entity represented by this model.
  ///
  /// Current domain invariants are deliberately re-applied here. Persisted
  /// records cannot bypass validation merely because they originated from
  /// storage.
  ///
  /// Throws [PersistenceRecordException] when the persisted snapshot no longer
  /// represents a valid [Merchant].
  Merchant toEntity() {
    try {
      return Merchant(
        id: MerchantId.fromString(id),
        name: name,
        createdAt: createdAt,
        modifiedAt: modifiedAt,
        archivedAt: archivedAt,
        deletedAt: deletedAt,
        entityVersion: entityVersion,
      );
    } on ArgumentError {
      throw const PersistenceRecordException(
        reason: 'Persisted merchant violates current domain invariants.',
      );
    }
  }

  /// Reads a required UTC ISO-8601 timestamp.
  static DateTime _readUtcDateTime(
    PersistenceRecordReader reader,
    String field,
  ) {
    final serializedValue = reader.requiredString(field);
    final parsedValue = DateTime.tryParse(serializedValue);

    if (parsedValue == null || !parsedValue.isUtc) {
      throw PersistenceRecordException(
        field: field,
        reason: 'Expected an ISO-8601 timestamp with a timezone.',
      );
    }

    return parsedValue.toUtc();
  }

  /// Reads an optional UTC ISO-8601 timestamp.
  static DateTime? _readOptionalUtcDateTime(
    PersistenceRecordReader reader,
    String field,
  ) {
    final serializedValue = reader.optionalString(field);

    if (serializedValue == null) {
      return null;
    }

    final parsedValue = DateTime.tryParse(serializedValue);

    if (parsedValue == null || !parsedValue.isUtc) {
      throw PersistenceRecordException(
        field: field,
        reason: 'Expected an ISO-8601 timestamp with a timezone or null.',
      );
    }

    return parsedValue.toUtc();
  }
}
