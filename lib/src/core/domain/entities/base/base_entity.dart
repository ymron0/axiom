import 'package:dart_mappable/dart_mappable.dart';

part 'base_entity.mapper.dart';

/// Minimal shared base type for domain entities that carry class-version
/// metadata.
///
/// Subclasses inherit [entityVersion] without being required to expose an
/// identifier, audit timestamps, or other persistence metadata. This type owns
/// only universal entity class-version metadata; identity and audit concerns
/// belong to the more specific entity foundations that add them.
///
/// ## Invariants
///
/// - [entityVersion] is always a positive integer.
/// - Version `1` is the lowest valid entity version; zero and negative values
///   are invalid.
/// - [entityVersion] is immutable for an entity snapshot.
///
/// ## Semantics
///
/// [entityVersion] identifies the class version used to interpret an entity
/// snapshot. It is not the entity's identity and is not domain state belonging
/// to a feature.
///
/// ## Contract
///
/// Subclasses must preserve immutable entity snapshots and must provide a
/// valid class version. A version change is represented by constructing a new
/// snapshot rather than mutating an existing instance.
@MappableClass()
abstract class BaseEntity with BaseEntityMappable {
  /// The class version associated with the entity snapshot.
  final int entityVersion;

  /// Initializes an entity with its current [entityVersion].
  ///
  /// Throws an [ArgumentError] when [entityVersion] is less than one.
  BaseEntity(this.entityVersion) {
    if (entityVersion < 1) {
      throw ArgumentError.value(
        entityVersion,
        'entityVersion',
        'Entity version must be greater than zero.',
      );
    }
  }
}
