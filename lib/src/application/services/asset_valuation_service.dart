import 'package:axiom/src/application/services/get_valuation_currency_service.dart';
import 'package:axiom/src/application/services/resolve_conversion_rate_service.dart';
import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/domain/services/asset_valuation_calculator.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_amount.dart';
import 'package:axiom/src/features/rates/domain/failures/rate_not_found_failure.dart';
import 'package:decimal/decimal.dart';

/// Values any supported asset in the configured fiat valuation currency.
///
/// The input may represent a Currency, CryptoAsset, StockAsset, or
/// CommodityAsset.
///
/// A successful known valuation is always expressed in the configured
/// [Currency], never in a crypto asset, stock, or commodity.
final class AssetValuationService {
  final GetValuationCurrencyService _getValuationCurrency;

  final ResolveConversionRateService _resolveConversionRate;
  final AssetValuationCalculator _calculator;
  /// Creates the valuation service.
  const AssetValuationService({
    required GetValuationCurrencyService getValuationCurrency,
    required ResolveConversionRateService resolveConversionRate,
    required AssetValuationCalculator calculator,
  }) : _getValuationCurrency = // ignore: prefer_initializing_formals
           getValuationCurrency,
       _resolveConversionRate = // ignore: prefer_initializing_formals
           resolveConversionRate,
       _calculator = calculator; // ignore: prefer_initializing_formals

  /// Values [amount] in the configured valuation currency at [at].
  ///
  /// Identity, zero, and unknown amounts do not require rate resolution.
  Future<Result<AssetAmount, BaseFailure>> call({
    required AssetAmount amount,
    required DateTime at,
  }) async {
    final currencyResult = await _getValuationCurrency();

    if (currencyResult case final Failure<BaseFailure> failure) {
      return failure;
    }

    final valuationCurrency = currencyResult.valueOrNull!;
    final valuationCurrencyId = valuationCurrency.id;

    final requiresConversionRate =
        amount.assetId != valuationCurrencyId &&
        amount.isKnownAmount &&
        amount.amount != Decimal.zero;

    if (!requiresConversionRate) {
      return Success(
        _calculator.calculate(
          amount: amount,
          valuationCurrencyId: valuationCurrencyId,
        ),
      );
    }

    final rateResult = await _resolveConversionRate(
      fromAssetId: amount.assetId,
      toAssetId: valuationCurrencyId,
      at: at,
    );

    return rateResult.when<Result<AssetAmount, BaseFailure>>(
      success: (conversionRate) => Success(
        _calculator.calculate(
          amount: amount,
          valuationCurrencyId: valuationCurrencyId,
          conversionRate: conversionRate,
        ),
      ),
      failure: (failure) {
        if (failure is RateNotFoundFailure) {
          // The quantity is known, but its value in the configured Currency
          // cannot currently be determined.
          return Success(
            _calculator.calculate(
              amount: amount,
              valuationCurrencyId: valuationCurrencyId,
            ),
          );
        }

        return failure;
      },
    );
  }
}
