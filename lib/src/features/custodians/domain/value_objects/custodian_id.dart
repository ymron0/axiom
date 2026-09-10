import 'package:axiom/src/core/domain/value_objects/unique_id.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'custodian_id.mapper.dart';

/// A type-safe identifier for a custodian.
///
/// Create one from a persisted value:
/// ```dart
/// final custodianId = CustodianId.fromString('custodian-123');
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
/// The Dart type represents custodian identity and must not be substituted for
/// an unrelated typed identifier with the same serialized value.
///
/// ## Contract
///
/// Use [fromString] for persisted values and [generate] for new custodian IDs.
@MappableClass()
final class CustodianId extends UniqueId with CustodianIdMappable {
  /// Creates a custodian identifier from its serialized [value].
  ///
  /// Throws an [ArgumentError] when [value] is blank.
  @MappableConstructor()
  CustodianId.fromString(super.value);

  /// Creates a custodian identifier with a newly generated Nano ID value.
  CustodianId.generate() : super.generate();
}
