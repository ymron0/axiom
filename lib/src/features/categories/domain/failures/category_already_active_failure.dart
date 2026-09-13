import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/categories/domain/failures/category_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'category_already_active_failure.mapper.dart';

/// Indicates that a category is already active.
@MappableClass()
final class CategoryAlreadyActiveFailure
    extends Failure<CategoryAlreadyActiveFailure>
    with CategoryAlreadyActiveFailureMappable
    implements CategoryFailure {
  /// Creates a category-already-active failure with optional details.
  const CategoryAlreadyActiveFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'categories.categoryAlreadyActive';

  @override
  CategoryAlreadyActiveFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
