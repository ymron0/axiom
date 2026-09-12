import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/application/failures/invalid_valuation_currency_failure.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/features/rates/application/services/validate_rate_assets_service.dart';
import 'package:axiom/src/features/rates/domain/entities/rate.dart';
import 'package:axiom/src/features/rates/domain/repositories/rate_repository.dart';

/// Shared workflow for validating and persisting a newly constructed rate.
///
/// Concrete rate-creation use cases construct their specific [Rate] subtype
/// and delegate the common validation and persistence workflow to this service.
final class CreateRateService {
  /// Creates a service backed by [repository].
  const CreateRateService({
    required RateRepository repository,
    required ValidateRateAssetsService validateRateAssets,
    required AssetId canonicalBridgeAssetId,
  }) : _repository = repository, // ignore: prefer_initializing_formals
       _validateRateAssets = // ignore: prefer_initializing_formals
           validateRateAssets,
       _canonicalBridgeAssetId = // ignore: prefer_initializing_formals
           canonicalBridgeAssetId;

  final RateRepository _repository;
  final ValidateRateAssetsService _validateRateAssets;
  final AssetId _canonicalBridgeAssetId;

  /// Validates referenced assets and persists [rate].
  ///
  /// Returns [rate] on success, or the validation/repository failure
  /// unchanged. Expected failures are represented by [Result]; programmer
  /// errors are not converted by this service.
  Future<Result<Rate, BaseFailure>> call(Rate rate) async {
    if (rate.quoteAssetId != _canonicalBridgeAssetId) {
      return InvalidValuationCurrencyFailure(
        message: 'Persisted rates must be quoted in USD.',
      );
    }

    final validationResult = await _validateRateAssets([rate]);

    return validationResult.when<Future<Result<Rate, BaseFailure>>>(
      success: (_) async {
        final createResult = await _repository.create(rate);

        return createResult.when<Result<Rate, BaseFailure>>(
          success: (_) => Success(rate),
          failure: (failure) => failure,
        );
      },
      failure: (failure) async => failure,
    );
  }
}
