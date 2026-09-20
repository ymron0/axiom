import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/categories/domain/failures/category_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'category_repository_failure.mapper.dart';

/// Indicates that a category repository operation could not complete.
@MappableClass()
final class CategoryRepositoryFailure extends Failure<CategoryRepositoryFailure>
    with CategoryRepositoryFailureMappable
    implements CategoryFailure {
  /// Creates a category repository failure with optional details.
  const CategoryRepositoryFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'categories.repository';

  @override
  CategoryRepositoryFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
