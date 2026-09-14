import 'package:axiom/src/core/result/result.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'referenced_asset_not_found_failure.mapper.dart';

/// Indicates that a persisted rate references an asset that does not exist.
@MappableClass()
final class ReferencedAssetNotFoundFailure
    extends Failure<ReferencedAssetNotFoundFailure>
    with ReferencedAssetNotFoundFailureMappable {
  /// Creates a referenced-asset failure with optional details.
  const ReferencedAssetNotFoundFailure({String? message}) : super(message);

  /// Stable identifier for this failure kind.
  static const typeId = 'rates.referencedAssetNotFound';

  /// Returns this failure as its declared failure type.
  @override
  ReferencedAssetNotFoundFailure get failureOrNull => this;

  /// Returns the stable identifier for this failure kind.
  @override
  String get type => typeId;
}
