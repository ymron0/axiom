import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/categories/domain/failures/category_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'category_kind_mismatch_failure.mapper.dart';

/// Indicates that related categories have incompatible financial kinds.
@MappableClass()
final class CategoryKindMismatchFailure
    extends Failure<CategoryKindMismatchFailure>
    with CategoryKindMismatchFailureMappable
    implements CategoryFailure {
  /// Creates a category-kind-mismatch failure with optional details.
  const CategoryKindMismatchFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'categories.categoryKindMismatch';

  @override
  CategoryKindMismatchFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
