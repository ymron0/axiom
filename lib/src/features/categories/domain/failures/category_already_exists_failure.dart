import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/categories/domain/failures/category_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'category_already_exists_failure.mapper.dart';

/// Indicates that a category conflicts with an existing category.
@MappableClass()
final class CategoryAlreadyExistsFailure
    extends Failure<CategoryAlreadyExistsFailure>
    with CategoryAlreadyExistsFailureMappable
    implements CategoryFailure {
  /// Creates a category-already-exists failure with optional details.
  const CategoryAlreadyExistsFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'categories.categoryAlreadyExists';

  @override
  CategoryAlreadyExistsFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
