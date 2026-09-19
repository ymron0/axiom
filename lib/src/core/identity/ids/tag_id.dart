import 'package:axiom/src/core/identity/unique_id.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'tag_id.mapper.dart';

/// A type-safe identifier for a tag.
///
/// Tags are reusable transaction metadata. A [TagId] identifies the canonical
/// tag definition referenced by transactions.
///
/// ## Invariants
///
/// The serialized value is non-empty, not solely whitespace, immutable, and
/// stable for the lifetime of this identifier. Generated values obey the same
/// validation contract.
///
/// Valid supplied values are preserved exactly without silent trimming or
/// normalization.
///
/// ## Contract
///
/// Use [fromString] for persisted values and [generate] for newly created tags.
@MappableClass()
final class TagId extends UniqueId with TagIdMappable {
  /// Creates a tag identifier from its serialized [value].
  ///
  /// Throws an [ArgumentError] when [value] is blank.
  @MappableConstructor()
  TagId.fromString(super.value);

  /// Creates a tag identifier with a newly generated Nano ID value.
  TagId.generate() : super.generate();
}
