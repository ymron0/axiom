import 'package:axiom/src/application/services/resolve_conversion_rate_service.dart';
import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/domain/services/asset_valuation_calculator.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:decimal/decimal.dart';

/// Values a collection of asset amounts into one target asset.
///
/// Each source amount is valued independently at [at]. The resulting values are
/// then combined into one signed total.
///
/// This service does not resolve the application's configured valuation
/// currency. The caller explicitly supplies [targetAssetId], which allows this
/// service to support both:
///
/// - an account's denomination asset; and
/// - the user's configured valuation currency.
///
/// Unknown source amounts are rejected because a concrete aggregate value
/// cannot be produced from incomplete quantities.
final class ValueAssetAmountsService {
  final ResolveConversionRateService _resolveConversionRate;
  final AssetValuationCalculator _calculator;

  /// Creates the multi-asset valuation service.
  const ValueAssetAmountsService({
    required ResolveConversionRateService resolveConversionRate,
    required AssetValuationCalculator calculator,
  }) : _resolveConversionRate = // ignore: prefer_initializing_formals
           resolveConversionRate,
       _calculator = calculator; // ignore: prefer_initializing_formals

  /// Values [amounts] into [targetAssetId] at [at].
  ///
  /// An empty collection produces zero in [targetAssetId].
  Future<Result<AssetAmount, BaseFailure>> call({
    required Iterable<AssetAmount> amounts,
    required AssetId targetAssetId,
    required DateTime at,
  }) async {
    var signedTotal = Decimal.zero;

    for (final amount in amounts) {
      if (amount.isUnknownAmount) {
        throw ArgumentError.value(
          amount,
          'amounts',
          'A multi-asset valuation cannot contain an unknown amount.',
        );
      }

      final valuationResult = await _valueAmount(
        amount: amount,
        targetAssetId: targetAssetId,
        at: at,
      );

      if (valuationResult case final Failure<BaseFailure> failure) {
        return failure;
      }

      signedTotal += _toSignedAmount(valuationResult.valueOrNull!);
    }

    return Success(
      _fromSignedAmount(assetId: targetAssetId, signedAmount: signedTotal),
    );
  }

  Future<Result<AssetAmount, BaseFailure>> _valueAmount({
    required AssetAmount amount,
    required AssetId targetAssetId,
    required DateTime at,
  }) async {
    if (amount.assetId == targetAssetId || amount.amount == Decimal.zero) {
      return Success(
        _calculator.calculate(
          amount: amount,
          valuationCurrencyId: targetAssetId,
        ),
      );
    }

    final rateResult = await _resolveConversionRate(
      fromAssetId: amount.assetId,
      toAssetId: targetAssetId,
      at: at,
    );

    if (rateResult case final Failure<BaseFailure> failure) {
      return failure;
    }

    return Success(
      _calculator.calculate(
        amount: amount,
        valuationCurrencyId: targetAssetId,
        conversionRate: rateResult.valueOrNull!,
      ),
    );
  }

  Decimal _toSignedAmount(AssetAmount amount) {
    return amount.isIncoming ? amount.amount : -amount.amount;
  }

  AssetAmount _fromSignedAmount({
    required AssetId assetId,
    required Decimal signedAmount,
  }) {
    if (signedAmount < Decimal.zero) {
      return AssetAmount.outgoing(assetId: assetId, amount: signedAmount.abs());
    }

    return AssetAmount.incoming(assetId: assetId, amount: signedAmount);
  }
}
