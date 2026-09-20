import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/rates/application/failures/unsupported_persisted_rate_quote_failure.dart';
import 'package:axiom/src/features/rates/application/services/validate_rate_assets_service.dart';
import 'package:axiom/src/features/rates/domain/entities/rate.dart';
import 'package:axiom/src/features/rates/domain/repositories/rate_repository.dart';

/// Shared workflow for validating and persisting a newly constructed rate.
///
/// Concrete rate-creation use cases construct the appropriate [Rate] subtype
/// and delegate shared validation and persistence to this service.
///
/// Persisted observations use one canonical bridge asset as their quote asset.
/// Under the current configuration that asset is USD.
class CreateRateService {
  final RateRepository _repository;
  final ValidateRateAssetsService _validateRateAssets;
  final AssetId _canonicalBridgeAssetId;

  /// Creates the shared rate persistence service.
  const CreateRateService({
    required RateRepository repository,
    required ValidateRateAssetsService validateRateAssets,
    required AssetId canonicalBridgeAssetId,
  }) : _repository = repository, // ignore: prefer_initializing_formals
       _validateRateAssets = // ignore: prefer_initializing_formals
           validateRateAssets,
       _canonicalBridgeAssetId = // ignore: prefer_initializing_formals
           canonicalBridgeAssetId;

  /// Validates and persists [rate].
  Future<Result<Rate, BaseFailure>> call(Rate rate) async {
    if (rate.quoteAssetId != _canonicalBridgeAssetId) {
      return UnsupportedPersistedRateQuoteFailure(
        message:
            'Persisted rates must be quoted in the canonical bridge asset '
            '${_canonicalBridgeAssetId.value}.',
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
