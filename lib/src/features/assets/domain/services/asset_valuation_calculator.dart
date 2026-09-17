import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:decimal/decimal.dart';

/// Converts an [AssetAmount] into a valuation currency using a resolved rate.
///
/// This calculator contains only deterministic financial arithmetic. It does
/// not retrieve settings, resolve exchange rates, access repositories, or
/// perform presentation rounding.
///
/// ## Rate semantics
///
/// [conversionRate], when required, represents the number of valuation-currency
/// units corresponding to one unit of [amount]'s asset.
///
/// For example:
///
/// ```text
/// amount.assetId       = EUR
/// valuationCurrencyId  = CHF
/// amount.amount        = 100
/// conversionRate       = 0.95
///
/// result               = CHF 95
/// ```
///
/// ## Identity semantics
///
/// When [amount] already uses [valuationCurrencyId], valuation is an identity
/// operation and the original immutable [AssetAmount] is returned.
///
/// A caller may omit [conversionRate] in this case. If a rate is supplied, it
/// must be exactly one.
///
/// ## Zero semantics
///
/// A zero amount does not require a conversion rate. Zero units of any asset
/// are worth zero units in the valuation currency.
///
/// The original direction is retained even though incoming and outgoing zero
/// are economically equivalent.
///
/// ## Unknown semantics
///
/// The `-1` sentinel supported by [AssetAmount] remains unknown after
/// conversion. No rate is required because applying a rate cannot make the
/// underlying quantity known.
///
/// A known non-zero cross-asset amount also becomes unknown when
/// [conversionRate] is absent. This represents an unavailable market
/// observation without inventing a value such as zero.
///
/// The returned unknown amount nevertheless uses [valuationCurrencyId], making
/// the asset represented by the result explicit.
///
/// ## Precision
///
/// No implicit rounding or conversion through `double` occurs. Multiplication
/// is performed directly with [Decimal]. Asset-specific display precision is a
/// presentation concern and must not alter the financial value here.
///
/// ## Contract
///
/// A supplied [conversionRate] must be strictly positive. A known, non-zero
/// cross-asset amount without a rate is returned as an unknown amount in
/// [valuationCurrencyId].
///
/// Throws [ArgumentError] when:
///
/// - a supplied conversion rate is zero or negative;
/// - a same-asset valuation supplies a conversion rate other than one.
final class AssetValuationCalculator {
  /// Creates a stateless asset valuation calculator.
  const AssetValuationCalculator();

  /// Values [amount] in [valuationCurrencyId].
  AssetAmount calculate({
    required AssetAmount amount,
    required AssetId valuationCurrencyId,
    Decimal? conversionRate,
  }) {
    _validateSuppliedRate(conversionRate);

    if (amount.assetId == valuationCurrencyId) {
      if (conversionRate != null && conversionRate != Decimal.one) {
        throw ArgumentError.value(
          conversionRate,
          'conversionRate',
          'Same-asset valuation requires a conversion rate of one.',
        );
      }

      return amount;
    }

    if (amount.isUnknownAmount || amount.amount == Decimal.zero) {
      return AssetAmount(
        assetId: valuationCurrencyId,
        amount: amount.amount,
        direction: amount.direction,
      );
    }

    final rate = conversionRate;

    if (rate == null) {
      return AssetAmount(
        assetId: valuationCurrencyId,
        amount: Decimal.fromInt(-1),
        direction: amount.direction,
      );
    }

    return AssetAmount(
      assetId: valuationCurrencyId,
      amount: amount.amount * rate,
      direction: amount.direction,
    );
  }

  void _validateSuppliedRate(Decimal? conversionRate) {
    if (conversionRate != null && conversionRate <= Decimal.zero) {
      throw ArgumentError.value(
        conversionRate,
        'conversionRate',
        'Conversion rate must be greater than zero.',
      );
    }
  }
}
