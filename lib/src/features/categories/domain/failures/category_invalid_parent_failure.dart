import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/categories/domain/failures/category_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'category_invalid_parent_failure.mapper.dart';

/// Indicates that a category cannot use the requested parent category.
@MappableClass()
final class CategoryInvalidParentFailure
    extends Failure<CategoryInvalidParentFailure>
    with CategoryInvalidParentFailureMappable
    implements CategoryFailure {
  /// Creates a category-invalid-parent failure with optional details.
  const CategoryInvalidParentFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'categories.categoryInvalidParent';

  @override
  CategoryInvalidParentFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
