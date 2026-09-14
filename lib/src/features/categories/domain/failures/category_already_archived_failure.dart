import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/categories/domain/failures/category_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'category_already_archived_failure.mapper.dart';

/// Indicates that a category is already archived.
@MappableClass()
final class CategoryAlreadyArchivedFailure
    extends Failure<CategoryAlreadyArchivedFailure>
    with CategoryAlreadyArchivedFailureMappable
    implements CategoryFailure {
  /// Creates a category-already-archived failure.
  const CategoryAlreadyArchivedFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'categories.categoryAlreadyArchived';

  @override
  CategoryAlreadyArchivedFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
