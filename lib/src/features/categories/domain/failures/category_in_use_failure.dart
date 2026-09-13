import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/categories/domain/failures/category_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'category_in_use_failure.mapper.dart';

/// Indicates that a category is referenced by another domain record.
@MappableClass()
final class CategoryInUseFailure extends Failure<CategoryInUseFailure>
    with CategoryInUseFailureMappable
    implements CategoryFailure {
  /// Creates a category-in-use failure with optional details.
  const CategoryInUseFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'categories.categoryInUse';

  @override
  CategoryInUseFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
