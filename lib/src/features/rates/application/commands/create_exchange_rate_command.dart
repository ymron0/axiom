import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:decimal/decimal.dart';

/// Input required to create and persist a new exchange-rate observation.
///
/// The command describes the rate's economic meaning; the use case supplies
/// the generated entity identity and creation timestamp.
final class CreateExchangeRateCommand {
  /// Creates an exchange-rate creation command.
  const CreateExchangeRateCommand({
    required this.baseAssetId,
    required this.quoteAssetId,
    required this.rate,
    required this.effectiveAt,
  });

  /// The asset for which one unit is being valued.
  final AssetId baseAssetId;

  /// The asset in which the base asset's value is expressed.
  final AssetId quoteAssetId;

  /// The number of quote-asset units per one base-asset unit.
  final Decimal rate;

  /// The instant at which the rate becomes economically effective.
  final DateTime effectiveAt;
}
