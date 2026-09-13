import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/categories/domain/failures/category_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'category_not_found_failure.mapper.dart';

/// Indicates that an expected category does not exist.
@MappableClass()
final class CategoryNotFoundFailure extends Failure<CategoryNotFoundFailure>
    with CategoryNotFoundFailureMappable
    implements CategoryFailure {
  /// Creates a category-not-found failure with optional details.
  const CategoryNotFoundFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'categories.categoryNotFound';

  @override
  CategoryNotFoundFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
