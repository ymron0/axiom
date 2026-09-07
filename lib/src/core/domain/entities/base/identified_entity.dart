
import 'package:axiom/src/core/domain/entities/base/base_entity.dart';
import 'package:axiom/src/core/domain/value_objects/unique_id.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'identified_entity.mapper.dart';

/// Base type for versioned domain entities with a stable [id].
///
/// In addition to its identity, each entity inherits the optimistic concurrency
/// revision defined by [BaseEntity].
@MappableClass()
abstract class IdentifiedEntity extends BaseEntity
    with IdentifiedEntityMappable {
  /// The identifier that distinguishes this entity from all others of its type.
  final UniqueId id;

  /// Initializes an entity with its [id] and current [entityVersion].
  ///
  /// Throws an [ArgumentError] when [entityVersion] is less than one.
  IdentifiedEntity({required this.id, required int entityVersion})
    : super(entityVersion);
}
