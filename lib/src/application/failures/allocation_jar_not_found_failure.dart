import 'package:axiom/src/core/result/result.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'allocation_jar_not_found_failure.mapper.dart';

/// Indicates that an allocation jar could not be found.
@MappableClass()
final class AllocationJarNotFoundFailure
    extends Failure<AllocationJarNotFoundFailure>
    with AllocationJarNotFoundFailureMappable {
  /// Creates a failure explaining why the allocation jar was not found.
  const AllocationJarNotFoundFailure({required String message})
    : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'application.allocationJarNotFound';

  @override
  AllocationJarNotFoundFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
