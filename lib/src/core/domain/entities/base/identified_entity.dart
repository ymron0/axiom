
import 'package:axiom/src/core/domain/entities/base/base_entity.dart';
import 'package:axiom/src/core/identity/unique_id.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'identified_entity.mapper.dart';

/// Base type for versioned domain entities with an immutable identity.
///
/// An entity is distinguished by its identity rather than by every field value;
/// snapshots with different mutable state can therefore represent the same
/// entity when they have the same [id]. In addition to its identity, each entity
/// inherits the optimistic concurrency revision defined by [BaseEntity].
///
/// ## Invariants
///
/// - Every instance has a non-null [id].
/// - [id] is a valid [UniqueId].
/// - [id] cannot change during the lifetime of an instance.
/// - Entity identity is distinct from value-object equality: the identity
///   identifies the entity, while the entity's other fields describe its state.
///
/// ## Semantics
///
/// The [id] is the stable identity assigned to an entity. This abstraction does
/// not itself guarantee uniqueness across all instances; allocation or
/// persistence boundaries own that responsibility.
///
/// ## Contract
///
/// Subclasses must provide a valid [UniqueId] and preserve it as the entity's
/// identity. They should expose immutable state and create a new snapshot when
/// domain changes are applied.
@MappableClass()
abstract class IdentifiedEntity extends BaseEntity
    with IdentifiedEntityMappable {
  /// The stable identity assigned to this entity.
  final UniqueId id;

  /// Initializes an entity with its [id] and current [entityVersion].
  ///
  /// Throws an [ArgumentError] when [entityVersion] is less than one.
  IdentifiedEntity({required this.id, required int entityVersion})
    : super(entityVersion);
}
