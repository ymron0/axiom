import 'package:axiom/src/core/result/result.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'allocation_category_kind_mismatch_failure.mapper.dart';

/// Indicates that there is a mismatch in the allocation category kind.
@MappableClass()
final class AllocationCategoryKindMismatchFailure
    extends Failure<AllocationCategoryKindMismatchFailure>
    with AllocationCategoryKindMismatchFailureMappable {
  /// Creates a failure explaining why the allocation category kind is mismatched.
  const AllocationCategoryKindMismatchFailure({required String message})
    : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'settings.allocationCategoryKindMismatch';

  @override
  AllocationCategoryKindMismatchFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
