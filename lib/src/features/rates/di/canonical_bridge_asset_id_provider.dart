import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'canonical_bridge_asset_id_provider.g.dart';

/// Provides the asset used to quote persisted rates.
@riverpod
AssetId canonicalBridgeAssetId(Ref ref) {
  return AssetId.fromString('asset-usd');
}
