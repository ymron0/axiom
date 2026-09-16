import 'package:axiom/src/core/domain/enums/entity_color.dart';
import 'package:axiom/src/core/domain/enums/entity_icon.dart';
import 'package:axiom/src/core/identity/ids/jar_id.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_exception.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_helpers.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_reader.dart';
import 'package:axiom/src/features/jars/data/models/jar_target_persistence_model.dart';
import 'package:axiom/src/features/jars/domain/entities/jar.dart';
import 'package:axiom/src/features/jars/domain/enums/jar_kind.dart';
import 'package:axiom/src/features/jars/domain/repositories/jar_repository.dart';
import 'package:axiom/src/features/jars/domain/value_objects/jar_target.dart';

/// Persistence representation of a [Jar].
///
/// This model owns the translation boundary between the Jars domain and the
/// Sembast-compatible primitive representation stored by the data layer.
///
/// ## Identity
///
/// The jar ID is stored as the Sembast record key rather than duplicated
/// inside the record value.
///
/// [recordKey] supplied to [fromRecord] is therefore the authoritative
/// persisted identity.
///
/// ## Record representation
///
/// Records contain persistence-safe primitive values and nested maps/lists
/// only.
///
/// Enumerations are stored using their stable enum names.
///
/// Entity timestamps are serialized as UTC ISO-8601 strings.
///
/// Calendar dates are serialized independently of time and timezone using
/// `YYYY-MM-DD` strings.
///
/// Decimal values are serialized as base-10 strings.
///
/// ## Targets
///
/// Every [JarTarget] is persisted as an independent nested record containing:
///
/// - its target amount,
/// - target asset identity,
/// - amount direction,
/// - effective start,
/// - optional effective end,
/// - optional desired target date.
///
/// Reconstructing the [Jar] through its domain constructor re-validates target
/// history, including overlap and common-asset invariants.
///
/// ## Deleted jars
///
/// Deleted jars are not valid persisted jar records.
///
/// [JarRepository.delete] physically removes the record and returns a
/// caller-retained snapshot containing a non-null `deletedAt`.
///
/// Consequently a record containing a non-null [deletedAt] indicates invalid
/// persisted state and is rejected by [toEntity].
///
/// The `deletedAt` field remains part of the persistent shape so malformed or
/// legacy records are detected instead of silently interpreted as active jars.
///
/// ## Failure behavior
///
/// Persisted values are treated as untrusted input.
///
/// Malformed values, unsupported enum values, invalid identifiers, invalid
/// decimals, malformed dates/timestamps, or records violating current Jars
/// domain invariants produce [PersistenceRecordException].
///
/// Persistent repositories translate that exception into
/// `JarPersistenceFailure` through the common persistence-operation guard.
final class JarPersistenceModel {
  /// Field containing the jar name.
  ///
  /// Public because repository search semantics depend on the persisted name.
  static const String nameField = 'name';

  /// Field containing the jar kind.
  ///
  /// Public because [JarRepository.getByKind] can query this field directly.
  static const String kindField = 'kind';

  /// Field containing the archive timestamp.
  ///
  /// Public because archive state is a repository query dimension.
  static const String archivedAtField = 'archivedAt';

  /// Field containing the deletion timestamp.
  ///
  /// Valid persisted jars must always contain `null` here.
  static const String deletedAtField = 'deletedAt';

  static const String _descriptionField = 'description';
  static const String _targetsField = 'targets';
  static const String _iconField = 'icon';
  static const String _colorField = 'color';
  static const String _sortOrderField = 'sortOrder';
  static const String _createdAtField = 'createdAt';
  static const String _modifiedAtField = 'modifiedAt';
  static const String _entityVersionField = 'entityVersion';

  /// Persisted jar identity.
  ///
  /// This value is represented by the Sembast record key and is intentionally
  /// omitted from [toRecord].
  final String id;

  /// Human-readable jar name.
  final String name;

  /// Optional user-provided jar description.
  final String? description;

  /// Financial behavior represented by the jar.
  final JarKind kind;

  /// Persisted target history.
  final List<JarTargetPersistenceModel> targets;

  /// Semantic fallback icon.
  final EntityIcon icon;

  /// Semantic display color.
  final EntityColor color;

  /// User-defined jar ordering position.
  final int sortOrder;

  /// Optional archive timestamp.
  final DateTime? archivedAt;

  /// Optional deletion timestamp.
  ///
  /// This must always be `null` for a valid stored jar.
  final DateTime? deletedAt;

  /// Creation timestamp normalized to UTC.
  final DateTime createdAt;

  /// Latest modification timestamp normalized to UTC.
  final DateTime modifiedAt;

  /// Domain entity class version.
  final int entityVersion;

  JarPersistenceModel._({
    required this.id,
    required this.name,
    required this.description,
    required this.kind,
    required List<JarTargetPersistenceModel> targets,
    required this.icon,
    required this.color,
    required this.sortOrder,
    required this.archivedAt,
    required this.deletedAt,
    required this.createdAt,
    required this.modifiedAt,
    required this.entityVersion,
  }) : targets = List<JarTargetPersistenceModel>.unmodifiable(targets);

  /// Creates a persistence model from [jar].
  ///
  /// Deleted jars cannot be persisted because deletion in [JarRepository] is
  /// physical.
  ///
  /// A deleted jar reaching this layer therefore represents a programming
  /// error rather than an expected persistence failure.
  factory JarPersistenceModel.fromEntity(Jar jar) {
    if (jar.deletedAt != null) {
      throw StateError(
        'Deleted jars cannot be represented as persisted jar records.',
      );
    }

    return JarPersistenceModel._(
      id: jar.id.value,
      name: jar.name,
      description: jar.description,
      kind: jar.kind,
      targets: jar.targets
          .map(JarTargetPersistenceModel.fromEntity)
          .toList(growable: false),
      icon: jar.icon,
      color: jar.color,
      sortOrder: jar.sortOrder,
      archivedAt: jar.archivedAt?.toUtc(),
      deletedAt: null,
      createdAt: jar.createdAt.toUtc(),
      modifiedAt: jar.modifiedAt.toUtc(),
      entityVersion: jar.entityVersion,
    );
  }

  /// Reconstructs a persistence model from [record].
  ///
  /// [recordKey] is the jar identity stored as the Sembast record key.
  ///
  /// Throws [PersistenceRecordException] when a persisted field has an invalid
  /// type or unsupported serialized value.
  factory JarPersistenceModel.fromRecord({
    required String recordKey,
    required PersistenceRecord record,
  }) {
    final reader = PersistenceRecordReader(record);

    final rawTargets = reader.requiredList(_targetsField);

    final targetModels = <JarTargetPersistenceModel>[];

    for (var index = 0; index < rawTargets.length; index++) {
      final path = '$_targetsField[$index]';

      final targetRecord = persistenceRecordFromListValue(
        rawTargets[index],
        field: path,
      );

      final target = withPersistenceRecordPath(
        path,
        () => JarTargetPersistenceModel.fromRecord(targetRecord),
      );

      targetModels.add(target);
    }

    return JarPersistenceModel._(
      id: recordKey,
      name: reader.requiredString(nameField),
      description: reader.optionalString(_descriptionField),
      kind: readPersistenceEnum<JarKind>(
        reader: reader,
        field: kindField,
        values: JarKind.values,
      ),
      targets: targetModels,
      icon: readPersistenceEnum<EntityIcon>(
        reader: reader,
        field: _iconField,
        values: EntityIcon.values,
      ),
      color: readPersistenceEnum<EntityColor>(
        reader: reader,
        field: _colorField,
        values: EntityColor.values,
      ),
      sortOrder: reader.requiredInt(_sortOrderField),
      archivedAt: _readOptionalUtcDateTime(reader, archivedAtField),
      deletedAt: _readOptionalUtcDateTime(reader, deletedAtField),
      createdAt: readPersistenceDateTime(reader, _createdAtField),
      modifiedAt: readPersistenceDateTime(reader, _modifiedAtField),
      entityVersion: readPositivePersistenceInt(reader, _entityVersionField),
    );
  }

  /// Converts this model into its Sembast-compatible record representation.
  ///
  /// [id] is intentionally omitted because it is represented by the Sembast
  /// record key.
  PersistenceRecord toRecord() {
    return <String, Object?>{
      nameField: name,
      _descriptionField: description,
      kindField: kind.name,
      _targetsField: targets
          .map((target) => target.toRecord())
          .toList(growable: false),
      _iconField: icon.name,
      _colorField: color.name,
      _sortOrderField: sortOrder,
      archivedAtField: archivedAt?.toUtc().toIso8601String(),
      deletedAtField: deletedAt?.toUtc().toIso8601String(),
      _createdAtField: createdAt.toUtc().toIso8601String(),
      _modifiedAtField: modifiedAt.toUtc().toIso8601String(),
      _entityVersionField: entityVersion,
    };
  }

  /// Reconstructs the domain [Jar] represented by this model.
  ///
  /// Throws [PersistenceRecordException] when persisted values violate current
  /// Jars-domain invariants.
  Jar toEntity() {
    if (deletedAt != null) {
      throw const PersistenceRecordException(
        field: deletedAtField,
        reason: 'Deleted jars must not remain in persistent jar storage.',
      );
    }

    try {
      return Jar(
        id: JarId.fromString(id),
        name: name,
        description: description,
        kind: kind,
        targets: targets
            .map((target) => target.toEntity())
            .toList(growable: false),
        icon: icon,
        color: color,
        sortOrder: sortOrder,
        archivedAt: archivedAt,
        deletedAt: null,
        createdAt: createdAt,
        modifiedAt: modifiedAt,
        entityVersion: entityVersion,
      );
    } on PersistenceRecordException {
      rethrow;
    } on ArgumentError {
      throw const PersistenceRecordException(
        reason: 'Persisted jar violates current domain invariants.',
      );
    }
  }

  /// Reads an optional UTC timestamp.
  static DateTime? _readOptionalUtcDateTime(
    PersistenceRecordReader reader,
    String field,
  ) {
    final rawValue = reader.optionalString(field);

    if (rawValue == null) {
      return null;
    }

    try {
      final parsed = DateTime.parse(rawValue);

      if (!parsed.isUtc) {
        throw const FormatException();
      }

      return parsed.toUtc();
    } on FormatException {
      throw PersistenceRecordException(
        field: field,
        reason: 'Expected a UTC ISO-8601 timestamp.',
      );
    }
  }
}
