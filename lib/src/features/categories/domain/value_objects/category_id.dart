import 'package:axiom/src/core/domain/value_objects/unique_id.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'category_id.mapper.dart';

/// A type-safe identifier for a category.
///
/// Create one from a persisted value:
/// ```dart
/// final categoryId = CategoryId.fromString('category-123');
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
/// The Dart type represents category identity and must not be substituted for
/// an unrelated typed identifier with the same serialized value.
///
/// ## Contract
///
/// Use [fromString] for persisted values and [generate] for new category IDs.
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
