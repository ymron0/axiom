part of 'create_asset_command.dart';

/// Input for creating a stock asset.
///
/// Stocks cannot be enabled as payment assets. Payment eligibility is therefore
/// intentionally absent from this command.
final class CreateStockAssetCommand extends CreateAssetCommand {
  /// Creates stock-asset creation input.
  const CreateStockAssetCommand({
    required super.name,
    required super.code,
    super.symbol,
    super.logo,
    required super.decimalPlaces,
  });
}
