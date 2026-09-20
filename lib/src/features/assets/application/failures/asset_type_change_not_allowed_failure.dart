import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/domain/failures/asset_failure.dart';
import 'package:dart_mappable/dart_mappable.dart';

part 'asset_type_change_not_allowed_failure.mapper.dart';

/// Indicates that an update attempted to change an asset's concrete subtype.
///
/// Asset subtype is immutable after creation because existing relationships may
/// rely on the asset's financial semantics.
///
/// For example, a Currency referenced as the configured valuation currency must
/// never later become a CryptoAsset or StockAsset while retaining the same ID.
@MappableClass()
final class AssetTypeChangeNotAllowedFailure
    extends Failure<AssetTypeChangeNotAllowedFailure>
    with AssetTypeChangeNotAllowedFailureMappable
    implements AssetFailure {
  /// Stable identifier for this failure kind.
  static const typeId = 'assets.assetTypeChangeNotAllowed';

  /// Creates the failure.
  const AssetTypeChangeNotAllowedFailure({required String message})
    : super(message);

  @override
  AssetTypeChangeNotAllowedFailure get failureOrNull => this;

  @override
  String get type => typeId;
}
