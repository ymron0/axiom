import 'package:axiom/src/features/assets/domain/value_objects/asset_code.dart';

/// Input required to create and persist a new asset.
///
/// Generated identity, version, and audit metadata are intentionally excluded.
final class CreateAssetCommand {
  /// Creates an asset creation command.
  const CreateAssetCommand({
    required this.name,
    required this.code,
    this.symbol,
    this.remoteLogoUrl,
    this.bundledLogoAsset,
    required this.decimalPlaces,
  });

  /// The asset's human-readable name.
  final String name;

  /// The asset's identifying code.
  final AssetCode code;

  /// The asset's optional display symbol.
  final String? symbol;

  /// An optional absolute HTTP(S) URL for the asset logo.
  final String? remoteLogoUrl;

  /// An optional path to a bundled logo asset.
  final String? bundledLogoAsset;

  /// The number of fractional decimal places supported by the asset.
  final int decimalPlaces;
}
