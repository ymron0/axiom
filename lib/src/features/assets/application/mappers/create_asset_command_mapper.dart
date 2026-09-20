import 'package:axiom/src/core/ports/clock/clock.dart';
import 'package:axiom/src/features/assets/application/commands/create_asset_command.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';

/// Converts asset-creation commands into their matching domain subtype.
///
/// This mapper centralizes the command-to-domain dispatch so the single-create
/// and atomic batch-create workflows cannot drift apart.
final class CreateAssetCommandMapper {
  /// Creates the stateless mapper.
  const CreateAssetCommandMapper();

  /// Creates the concrete [Asset] described by [command].
  ///
  /// The supplied [clock] is forwarded to the corresponding domain factory so
  /// creation remains deterministic in tests.
  Asset toEntity({required CreateAssetCommand command, required Clock clock}) {
    return switch (command) {
      CreateCurrencyCommand() => Currency.create(
        name: command.name,
        code: command.code,
        symbol: command.symbol,
        logo: command.logo,
        decimalPlaces: command.decimalPlaces,
        clock: clock,
      ),
      CreateCryptoAssetCommand() => CryptoAsset.create(
        name: command.name,
        code: command.code,
        symbol: command.symbol,
        logo: command.logo,
        decimalPlaces: command.decimalPlaces,
        paymentEnabled: command.paymentEnabled,
        clock: clock,
      ),
      CreateStockAssetCommand() => StockAsset.create(
        name: command.name,
        code: command.code,
        symbol: command.symbol,
        logo: command.logo,
        decimalPlaces: command.decimalPlaces,
        clock: clock,
      ),
      CreateCommodityAssetCommand() => CommodityAsset.create(
        name: command.name,
        code: command.code,
        symbol: command.symbol,
        logo: command.logo,
        decimalPlaces: command.decimalPlaces,
        clock: clock,
      ),
    };
  }
}
