import 'package:axiom/src/core/identity/unique_id.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'rate_id.mapper.dart';

/// A type-safe identifier for a rate.
///
/// Create one from a persisted value:
/// ```dart
/// final rateId = RateId.fromString('rate-123');
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
/// The Dart type represents rate identity and must not be substituted for an
/// unrelated typed identifier with the same serialized value.
///
/// ## Contract
///
/// Use [fromString] for persisted values and [generate] for new rate IDs.
@MappableClass()
final class RateId extends UniqueId with RateIdMappable {
  /// Creates a rate identifier from its serialized [value].
  ///
  /// Throws an [ArgumentError] when [value] is blank.
  @MappableConstructor()
  RateId.fromString(super.value);

  /// Creates a rate identifier with a newly generated Nano ID value.
  RateId.generate() : super.generate();
}
