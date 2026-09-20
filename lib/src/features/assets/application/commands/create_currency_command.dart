part of 'create_asset_command.dart';

/// Input for creating a fiat currency.
///
/// Currency payment eligibility is a domain invariant and is therefore not
/// configurable through this command. Currency instances are always payment
/// enabled.
final class CreateCurrencyCommand extends CreateAssetCommand {
  /// Creates currency creation input.
  const CreateCurrencyCommand({
    required super.name,
    required super.code,
    super.symbol,
    super.logo,
    required super.decimalPlaces,
  });
}
