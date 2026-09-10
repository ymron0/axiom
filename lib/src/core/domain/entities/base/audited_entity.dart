import 'package:axiom/src/core/domain/entities/base/identified_entity.dart';
import 'package:axiom/src/core/domain/value_objects/unique_id.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'audited_entity.mapper.dart';

/// Base type for identified entities that record immutable lifecycle metadata.
///
/// Each entity inherits an identifier and concurrency revision from
/// [IdentifiedEntity], then adds its creation and most recent modification
/// time. These timestamps describe the entity's lifecycle, not its identity.
///
/// ## Invariants
///
/// - [createdAt] is immutable historical metadata for the entity snapshot.
/// - [modifiedAt] is the latest known modification timestamp for the snapshot.
/// - [modifiedAt] may equal [createdAt], but must not precede it.
/// - Timestamp metadata does not change the entity's identity.
///
/// ## Semantics
///
/// [createdAt] records when the entity was created, while [modifiedAt] records
/// the latest modification known to the caller. Both values are supplied by
/// the caller or an application workflow; this domain type does not read a
/// system clock. Workflows that use the project's `Clock` abstraction should
/// prefer its `nowUtc` value when a canonical UTC timestamp is required.
///
/// ## Contract
///
/// Subclasses must preserve the timestamps as immutable snapshot metadata and
/// provide values that satisfy the chronology invariant. Updating audit
/// metadata produces a new entity snapshot rather than mutating this one.
@MappableClass()
abstract class AuditedEntity extends IdentifiedEntity
    with AuditedEntityMappable {
  /// The instant when the entity was first created.
  final DateTime createdAt;

  /// The instant when the entity was most recently modified.
  final DateTime modifiedAt;

  /// Initializes an audited entity with its identity, revision, and timestamps.
  ///
  /// Throws an [ArgumentError] when [entityVersion] is less than one or
  /// [modifiedAt] precedes [createdAt].
  AuditedEntity({
    required super.id,
    required super.entityVersion,
    required this.createdAt,
    required this.modifiedAt,
  }) {
    if (modifiedAt.isBefore(createdAt)) {
      throw ArgumentError.value(
        modifiedAt,
        'modifiedAt',
        'Modification time cannot precede creation time.',
      );
    }
  }
}
