part of 'fee_expression.dart';

/// A fee expressed directly as an amount of an asset.
///
/// For example:
///
/// ```text
/// 5 CHF
/// 2.50 USD
/// 0.0001 BTC
/// ```
///
/// The amount represents an outgoing fee payment.
///
/// When attached to a `LedgerEntry`, this amount must exactly match the
/// ledger entry's transaction amount.
@MappableClass(discriminatorValue: 'assetAmount')
final class AssetAmountFeeExpression extends FeeExpression
    with AssetAmountFeeExpressionMappable {
  /// Asset amount originally entered as the fee.
  final AssetAmount amount;

  /// Creates an asset-amount fee expression.
  AssetAmountFeeExpression({required this.amount}) {
    if (!amount.isOutgoing) {
      throw ArgumentError.value(
        amount,
        'amount',
        'An asset-amount fee expression must be outgoing.',
      );
    }
  }
}
