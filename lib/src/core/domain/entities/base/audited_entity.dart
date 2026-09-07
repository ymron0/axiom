import 'package:axiom/src/core/domain/entities/base/identified_entity.dart';
import 'package:axiom/src/core/domain/value_objects/unique_id.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'audited_entity.mapper.dart';

/// Base type for identified entities that record lifecycle timestamps.
///
/// Each entity inherits an identifier and concurrency revision from
/// [IdentifiedEntity], then adds its creation and most recent modification time.
@MappableClass()
abstract class AuditedEntity extends IdentifiedEntity
    with AuditedEntityMappable {
  /// The instant when the entity was first created.
  final DateTime createdAt;

  /// The instant when the entity was most recently modified.
  final DateTime modifiedAt;

  /// Initializes an audited entity with its identity, revision, and timestamps.
  ///
  /// Throws an [ArgumentError] when [id] is blank, [entityVersion] is less than
  /// one, or [modifiedAt] precedes [createdAt].
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
