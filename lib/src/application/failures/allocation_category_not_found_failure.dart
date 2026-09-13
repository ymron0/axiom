import 'package:axiom/src/core/result/result.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'allocation_category_not_found_failure.mapper.dart';

/// Indicates that an allocation category could not be found.
@MappableClass()
final class AllocationCategoryNotFoundFailure
    extends Failure<AllocationCategoryNotFoundFailure>
    with AllocationCategoryNotFoundFailureMappable {
  /// Creates a failure explaining why the allocation category was not found.
  const AllocationCategoryNotFoundFailure({required String message})
    : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'settings.allocationCategoryNotFound';

  @override
  AllocationCategoryNotFoundFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
