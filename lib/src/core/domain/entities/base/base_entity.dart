import 'package:dart_mappable/dart_mappable.dart';

part 'base_entity.mapper.dart';

/// Shared base type for domain entities that support version tracking.
///
/// Subclasses inherit [entityVersion] without being required to expose an
/// identifier, audit timestamps, or other persistence metadata.
@MappableClass()
abstract class BaseEntity with BaseEntityMappable {
  /// The entity revision used for optimistic concurrency checks.
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
