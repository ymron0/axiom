import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/rates/domain/failures/rate_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'rate_not_found_failure.mapper.dart';

/// Indicates that no rate observation matched the requested lookup.
@MappableClass()
final class RateNotFoundFailure extends Failure<RateNotFoundFailure>
    with RateNotFoundFailureMappable
    implements RateFailure {
  /// Creates a rate-not-found failure with optional details.
  const RateNotFoundFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'rates.rateNotFound';

  @override
  RateNotFoundFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
