import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/rates/application/services/validate_rate_assets_service.dart';
import 'package:axiom/src/features/rates/domain/entities/rate.dart';
import 'package:axiom/src/features/rates/domain/repositories/rate_repository.dart';

/// Retrieves the applicable persisted rate for an asset pair at a given time.
///
/// The lookup preserves pair orientation. A request for `EUR/USD`, for
/// example, does not match `USD/EUR`.
///
/// The repository determines temporal resolution. The expected semantics are
/// to return the most recent rate whose effective timestamp is less than or
/// equal to [at]. A future rate must never be returned.
///
/// This use case does not invert rates, calculate cross-rates, or otherwise
/// resolve arbitrary asset pairs.
///
/// Missing rates are returned as a failure according to
/// [RateRepository.getAtOrBefore].
final class GetRateAtUseCase {
  /// Creates a use case backed by [repository].
  const GetRateAtUseCase({
    required this.repository,
    required ValidateRateAssetsService validateRateAssets,
  }) : _validateRateAssets = // ignore: prefer_initializing_formals
           validateRateAssets;

  /// Repository used for rate lookup.
  final RateRepository repository;
  final ValidateRateAssetsService _validateRateAssets;

  /// Retrieves the applicable rate for
  /// [baseAssetId]/[quoteAssetId] at [at].
  ///
  /// Asset-reference validation failures are returned unchanged.
  Future<Result<Rate, BaseFailure>> call({
    required AssetId baseAssetId,
    required AssetId quoteAssetId,
    required DateTime at,
  }) async {
    final rateResult = await repository.getAtOrBefore(
      baseAssetId: baseAssetId,
      quoteAssetId: quoteAssetId,
      effectiveAt: at,
    );

    return rateResult.when<Future<Result<Rate, BaseFailure>>>(
      success: (rate) async {
        final validationResult = await _validateRateAssets([rate]);

        return validationResult.when<Result<Rate, BaseFailure>>(
          success: (_) => Success(rate),
          failure: (failure) => failure,
        );
      },
      failure: (failure) async => failure,
    );
  }
}
