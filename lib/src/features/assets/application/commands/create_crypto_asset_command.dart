part of 'create_asset_command.dart';

/// Input for creating a crypto asset.
///
/// Crypto assets are the only non-fiat asset type whose payment eligibility
/// may be configured by the user.
final class CreateCryptoAssetCommand extends CreateAssetCommand {
  /// Whether this crypto asset may be used as a payment asset.
  ///
  /// Defaults to `false`.
  final bool paymentEnabled;

  /// Creates crypto-asset creation input.
  const CreateCryptoAssetCommand({
    required super.name,
    required super.code,
    super.symbol,
    super.logo,
    required super.decimalPlaces,
    this.paymentEnabled = false,
  });
}
