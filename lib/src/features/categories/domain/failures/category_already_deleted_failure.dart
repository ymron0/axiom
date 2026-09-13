import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/categories/domain/failures/category_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'category_already_deleted_failure.mapper.dart';

/// Indicates that a category is already marked as deleted.
@MappableClass()
final class CategoryAlreadyDeletedFailure
    extends Failure<CategoryAlreadyDeletedFailure>
    with CategoryAlreadyDeletedFailureMappable
    implements CategoryFailure {
  /// Creates a category-already-deleted failure with optional details.
  const CategoryAlreadyDeletedFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'categories.categoryAlreadyDeleted';

  @override
  CategoryAlreadyDeletedFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
