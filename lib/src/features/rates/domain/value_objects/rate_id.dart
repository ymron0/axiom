import 'package:axiom/src/core/domain/value_objects/unique_id.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'rate_id.mapper.dart';

/// A type-safe identifier for a rate.
///
/// Create one from a persisted value:
/// ```dart
/// final rateId = RateId.fromString('rate-123');
/// ```
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
