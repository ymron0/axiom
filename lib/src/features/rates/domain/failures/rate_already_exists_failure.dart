import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/rates/domain/failures/rate_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'rate_already_exists_failure.mapper.dart';

/// Indicates that a rate with the requested identity already exists.
@MappableClass()
final class RateAlreadyExistsFailure extends Failure<RateAlreadyExistsFailure>
    with RateAlreadyExistsFailureMappable
    implements RateFailure {
  /// Creates a rate-already-exists failure with optional details.
  const RateAlreadyExistsFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'rates.rateAlreadyExists';

  @override
  RateAlreadyExistsFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
