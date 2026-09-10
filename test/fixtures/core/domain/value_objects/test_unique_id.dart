import 'package:axiom/src/core/identity/unique_id.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'test_unique_id.mapper.dart';

/// Identifier used to verify subtype-sensitive equality.
@MappableClass()
final class TestUniqueId extends UniqueId with TestUniqueIdMappable {
  TestUniqueId(super.value);

  /// Creates an identifier with a generated Nano ID value.
  TestUniqueId.generate() : super.generate();
}
