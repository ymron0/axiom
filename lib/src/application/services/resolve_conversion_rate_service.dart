import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/rates/application/use_cases/get_rate_at_use_case.dart';
import 'package:axiom/src/features/rates/domain/entities/rate.dart';
import 'package:axiom/src/features/rates/domain/services/rate_conversion_service.dart';
import 'package:decimal/decimal.dart';

/// Resolves the conversion rate between two assets at a point in time.
///
/// The returned value is the number of quote-asset units equivalent to one
/// unit of the base asset. Resolution uses rates persisted as
/// `asset/canonicalBridgeAsset` pairs and supports direct rates, inversion
/// from the bridge asset, and cross-rates between two non-bridge assets.
///
/// For example, when USD is the canonical bridge asset:
///
/// ```text
/// EUR/USD -> EUR/USD
/// USD/EUR -> 1 / (EUR/USD)
/// EUR/CHF -> (EUR/USD) / (CHF/USD)
/// ```
///
/// Rates are retrieved at or before the requested instant; a future rate is
/// not used. Requests for the same asset return [Decimal.one] without a rate
/// lookup. Lookup and asset-validation failures are returned unchanged.
/// Calculation and rate-orientation invariants are delegated to
/// [RateConversionService].
final class ResolveConversionRateService {
  /// Creates a conversion-rate resolver.
  const ResolveConversionRateService({
    required GetRateAtUseCase getRateAt,
    required AssetId canonicalBridgeAssetId,
    required RateConversionService rateConversion,
  }) : _getRateAt = getRateAt, // ignore: prefer_initializing_formals
       _canonicalBridgeAssetId = // ignore: prefer_initializing_formals
           canonicalBridgeAssetId,
       _rateConversion = rateConversion; // ignore: prefer_initializing_formals

  final GetRateAtUseCase _getRateAt;
  final AssetId _canonicalBridgeAssetId;
  final RateConversionService _rateConversion;

  /// Resolves the number of [toAssetId] units per one [fromAssetId] unit.
  ///
  /// Loads only the required asset-to-bridge observations and delegates
  /// inversion and cross-rate calculations to [RateConversionService].
  Future<Result<Decimal, BaseFailure>> call({
    required AssetId fromAssetId,
    required AssetId toAssetId,
    required DateTime at,
  }) async {
    if (fromAssetId == toAssetId) {
      return Success(Decimal.one);
    }

    Rate? baseBridgeRate;
    if (fromAssetId != _canonicalBridgeAssetId) {
      final result = await _getBridgeRate(fromAssetId, at);
      if (result case final Failure<BaseFailure> failure) {
        return failure;
      }
      baseBridgeRate = result.valueOrNull;
    }

    Rate? quoteBridgeRate;
    if (toAssetId != _canonicalBridgeAssetId) {
      final result = await _getBridgeRate(toAssetId, at);
      if (result case final Failure<BaseFailure> failure) {
        return failure;
      }
      quoteBridgeRate = result.valueOrNull;
    }

    return Success(
      _rateConversion.resolve(
        baseAssetId: fromAssetId,
        quoteAssetId: toAssetId,
        bridgeAssetId: _canonicalBridgeAssetId,
        baseBridgeRate: baseBridgeRate,
        quoteBridgeRate: quoteBridgeRate,
      ),
    );
  }

  Future<Result<Rate, BaseFailure>> _getBridgeRate(
    AssetId baseAssetId,
    DateTime at,
  ) {
    return _getRateAt(
      baseAssetId: baseAssetId,
      quoteAssetId: _canonicalBridgeAssetId,
      at: at,
    );
  }
}
