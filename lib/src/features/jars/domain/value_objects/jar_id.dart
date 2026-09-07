import 'package:axiom/src/core/domain/value_objects/unique_id.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'jar_id.mapper.dart';

/// A type-safe identifier for a jar.
///
/// Create one from a persisted value:
/// ```dart
/// final jarId = JarId.fromString('jar-123');
/// ```
@MappableClass()
final class JarId extends UniqueId with JarIdMappable {
  /// Creates a jar identifier from its serialized [value].
  ///
  /// Throws an [ArgumentError] when [value] is blank.
  @MappableConstructor()
  JarId.fromString(super.value);

  /// Creates a jar identifier with a newly generated Nano ID value.
  JarId.generate() : super.generate();
}
