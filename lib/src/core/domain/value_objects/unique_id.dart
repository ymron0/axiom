import 'package:dart_mappable/dart_mappable.dart';
import 'package:nanoid/nanoid.dart';

part 'unique_id.mapper.dart';

/// Base value object for type-safe entity identifiers.
///
/// The original [value] is preserved for serialization. Concrete subclasses
/// prevent identifiers belonging to different entity types from being mixed.
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
