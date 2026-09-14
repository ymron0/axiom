import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/categories/domain/failures/category_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'category_not_archived_failure.mapper.dart';

/// Indicates that an operation requiring an archived category received an
/// active category.
@MappableClass()
final class CategoryNotArchivedFailure
    extends Failure<CategoryNotArchivedFailure>
    with CategoryNotArchivedFailureMappable
    implements CategoryFailure {
  /// Creates a category-not-archived failure.
  const CategoryNotArchivedFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'categories.categoryNotArchived';

  @override
  CategoryNotArchivedFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
