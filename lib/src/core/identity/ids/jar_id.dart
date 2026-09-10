import 'package:axiom/src/core/identity/unique_id.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'jar_id.mapper.dart';

/// A type-safe identifier for a jar.
///
/// Create one from a persisted value:
/// ```dart
/// final jarId = JarId.fromString('jar-123');
/// ```
///
/// ## Invariants
///
/// The serialized value is non-empty, not solely whitespace, immutable, and
/// stable for the lifetime of this identifier. Generated values obey the same
/// validation contract. Valid supplied values are preserved exactly without
/// silent trimming or normalization.
///
/// ## Semantics
///
/// The Dart type represents jar identity and must not be substituted for an
/// unrelated typed identifier with the same serialized value.
///
/// ## Contract
///
/// Use [fromString] for persisted values and [generate] for new jar IDs.
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
