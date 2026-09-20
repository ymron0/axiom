import 'package:axiom/src/core/result/result.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'rate_source_acquisition_failure.mapper.dart';

/// Indicates that an external rate or market-price observation could not be
/// acquired safely.
///
/// Provider-specific and data-layer failures must be translated into this
/// application-facing failure before crossing the source-adapter boundary.
@MappableClass()
final class RateSourceAcquisitionFailure
    extends Failure<RateSourceAcquisitionFailure>
    with RateSourceAcquisitionFailureMappable {
  /// Creates a source-acquisition failure.
  const RateSourceAcquisitionFailure({required String message})
    : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'rates.source.acquisition';

  @override
  RateSourceAcquisitionFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
