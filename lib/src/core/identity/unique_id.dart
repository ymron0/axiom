import 'package:dart_mappable/dart_mappable.dart';
import 'package:nanoid/nanoid.dart';

part 'unique_id.mapper.dart';

/// Stable serialized identity for a domain entity.
///
/// [UniqueId] is the common, feature-independent identifier abstraction.
/// Concrete subclasses provide type safety so identifiers belonging to
/// different entity types cannot be mixed.
///
/// ## Invariants
///
/// - [value] is non-empty.
/// - [value] is not solely whitespace.
/// - The identifier value is immutable after construction.
/// - Generated identifiers obey the same validation contract as supplied
///   identifiers.
/// - A valid supplied value is preserved exactly.
/// - A valid supplied value is not silently trimmed or otherwise normalized.
/// - The serialized value remains stable for the lifetime of the object.
///
/// ## Semantics
///
/// This value object represents the stable serialized identity used by a
/// domain entity. It represents identity, not an entity itself.
///
/// ## Contract
///
/// Construct an instance from a serialized identifier or generate a new
/// NanoID. Invalid identifiers fail immediately with [ArgumentError].
@MappableClass()
abstract class UniqueId with UniqueIdMappable {
  /// The stable serialized representation of this identifier.
  final String value;

  /// Creates an identifier from an existing serialized [value].
  ///
  /// Throws an [ArgumentError] when [value] is blank.
  UniqueId(String value) : value = _validateValue(value);

  /// Creates an identifier with a newly generated Nano ID value.
  UniqueId.generate() : value = _validateValue(nanoid());

  static String _validateValue(String value) {
    if (value.trim().isEmpty) {
      throw ArgumentError.value(value, 'value', 'Identifier cannot be blank.');
    }

    return value;
  }
}
