part of 'create_asset_command.dart';

/// Input for creating a commodity asset.
///
/// Commodities cannot be enabled as payment assets. Payment eligibility is
/// therefore intentionally absent from this command.
final class CreateCommodityAssetCommand extends CreateAssetCommand {
  /// Creates commodity-asset creation input.
  const CreateCommodityAssetCommand({
    required super.name,
    required super.code,
    super.symbol,
    super.logo,
    required super.decimalPlaces,
  });
}
