import 'package:axiom/src/core/domain/value_objects/unique_id.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'category_id.mapper.dart';

/// A type-safe identifier for a category.
///
/// Create one from a persisted value:
/// ```dart
/// final categoryId = CategoryId.fromString('category-123');
/// ```
@MappableClass()
final class CategoryId extends UniqueId with CategoryIdMappable {
  /// Creates a category identifier from its serialized [value].
  ///
  /// Throws an [ArgumentError] when [value] is blank.
  @MappableConstructor()
  CategoryId.fromString(super.value);

  /// Creates a category identifier with a newly generated Nano ID value.
  CategoryId.generate() : super.generate();
}
