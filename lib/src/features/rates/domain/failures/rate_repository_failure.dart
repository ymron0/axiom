import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/rates/domain/failures/rate_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'rate_repository_failure.mapper.dart';

/// Indicates that a rate repository operation could not complete.
@MappableClass()
final class RateRepositoryFailure extends Failure<RateRepositoryFailure>
    with RateRepositoryFailureMappable
    implements RateFailure {
  /// Creates a rate repository failure with optional details.
  const RateRepositoryFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'rates.repository';

  @override
  RateRepositoryFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
