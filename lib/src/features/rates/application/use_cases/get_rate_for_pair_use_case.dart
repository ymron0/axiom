import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/failures/record_not_found_failure.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/application/failures/invalid_valuation_currency_failure.dart';
import 'package:axiom/src/features/assets/application/use_cases/get_asset_by_code_use_case.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_code.dart';
import 'package:axiom/src/features/rates/application/services/validate_rate_assets_service.dart';
import 'package:axiom/src/features/rates/domain/entities/rate.dart';
import 'package:axiom/src/features/rates/domain/repositories/rate_repository.dart';

/// Retrieves persisted rates for an exact asset pair.
///
/// The lookup preserves pair orientation. A request for `EUR/USD`, for
/// example, does not match a stored `USD/EUR` rate.
///
/// This use case performs no inversion, cross-rate calculation, or fallback
/// resolution. More complex rate resolution belongs to the application
/// service responsible for resolving arbitrary asset pairs.
///
/// A successful empty list indicates that no persisted rates exist for the
/// requested pair.
final class GetRateForPairUseCase {
  /// Creates a use case backed by [repository] and [getAssetByCode].
  const GetRateForPairUseCase({
    required RateRepository repository,
    required GetAssetByCodeUseCase getAssetByCode,
    required ValidateRateAssetsService validateRateAssets,
  }) : _repository = repository, // ignore: prefer_initializing_formals
       _getAssetByCode = getAssetByCode, // ignore: prefer_initializing_formals
       _validateRateAssets = // ignore: prefer_initializing_formals
           validateRateAssets;

  final RateRepository _repository;
  final GetAssetByCodeUseCase _getAssetByCode;
  final ValidateRateAssetsService _validateRateAssets;

  /// Retrieves persisted rates for [baseAssetId]/[quoteAssetId].
  ///
  /// Asset-reference validation failures are returned unchanged.
  Future<Result<List<Rate>, BaseFailure>> call({
    required AssetId baseAssetId,
    required AssetId quoteAssetId,
  }) async {
    final usdResult = await _getAssetByCode.call(AssetCode('USD'));

    return usdResult.when(
      success: (assets) async {
        if (assets.isEmpty) {
          return RecordNotFoundFailure(message: 'USD asset is not configured.');
        }

        final usd = assets.first;
        if (quoteAssetId != usd.id) {
          return InvalidValuationCurrencyFailure(
            message: 'Persisted rates must be quoted in USD.',
          );
        }

        final ratesResult = await _repository.getByPair(
          baseAssetId: baseAssetId,
          quoteAssetId: quoteAssetId,
        );

        return ratesResult.when<Future<Result<List<Rate>, BaseFailure>>>(
          success: (rates) async {
            final validationResult = await _validateRateAssets(rates);

            return validationResult.when<Result<List<Rate>, BaseFailure>>(
              success: (_) => Success(rates),
              failure: (failure) => failure,
            );
          },
          failure: (failure) async => failure,
        );
      },
      failure: (failure) async => failure,
    );
  }
}
