import 'package:axiom/src/core/domain/value_objects/unique_id.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'custodian_id.mapper.dart';

/// A type-safe identifier for a custodian.
///
/// Create one from a persisted value:
/// ```dart
/// final custodianId = CustodianId.fromString('custodian-123');
/// ```
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
