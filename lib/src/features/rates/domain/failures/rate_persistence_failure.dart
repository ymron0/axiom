import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/rates/domain/failures/rate_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'rate_persistence_failure.mapper.dart';

/// Indicates that rate persistence failed unexpectedly.
@MappableClass()
final class RatePersistenceFailure extends Failure<RatePersistenceFailure>
    with RatePersistenceFailureMappable
    implements RateFailure {
  /// Creates a rate-persistence failure with optional details.
  const RatePersistenceFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'rates.persistence';

  @override
  RatePersistenceFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
