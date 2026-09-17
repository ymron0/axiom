import 'package:axiom/src/core/result/result.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'rate_synchronization_conflict_failure.mapper.dart';

/// Indicates that two different rates claim the same financial observation
/// timestamp for the same asset pair.
///
/// The current repository contract has no observation-replacement operation.
/// Silently inserting another rate at the same effective timestamp would make
/// temporal selection ambiguous, while silently ignoring the changed value
/// would hide a provider correction.
///
/// Synchronization therefore fails explicitly.
@MappableClass()
final class RateSynchronizationConflictFailure
    extends Failure<RateSynchronizationConflictFailure>
    with RateSynchronizationConflictFailureMappable {
  /// Creates the conflict failure.
  const RateSynchronizationConflictFailure({required String message})
    : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'rates.synchronization.conflict';

  @override
  RateSynchronizationConflictFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
