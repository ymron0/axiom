import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/rates/domain/entities/rate.dart';
import 'package:axiom/src/features/rates/domain/repositories/rate_repository.dart';
import 'package:axiom/src/features/rates/domain/services/rate_conversion_service.dart';
import 'package:decimal/decimal.dart';

/// Resolves the conversion rate between two assets at a point in time.
///
/// Resolution uses persisted rates quoted in the canonical bridge asset.
final class ResolveConversionRateService {
  /// Creates a conversion-rate resolver.
  const ResolveConversionRateService({
    required RateRepository repository,
    required AssetId canonicalBridgeAssetId,
    required RateConversionService rateConversion,
  }) : _repository = repository, // ignore: prefer_initializing_formals
       _canonicalBridgeAssetId = // ignore: prefer_initializing_formals
           canonicalBridgeAssetId,
       _rateConversion = rateConversion; // ignore: prefer_initializing_formals

  final RateRepository _repository;
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
    return _repository.getAtOrBefore(
      baseAssetId: baseAssetId,
      quoteAssetId: _canonicalBridgeAssetId,
      effectiveAt: at,
    );
  }
}
