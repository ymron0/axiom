import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/identity/ids/rate_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/rates/application/services/validate_rate_assets_service.dart';
import 'package:axiom/src/features/rates/domain/entities/rate.dart';
import 'package:axiom/src/features/rates/domain/repositories/rate_repository.dart';

/// Retrieves a persisted rate by its identity.
///
/// This use case performs an identity lookup only. It does not resolve asset
/// pairs, apply temporal lookup semantics, invert rates, or calculate
/// cross-rates.
///
final class GetRateByIdUseCase {
  /// Creates a use case backed by [repository].
  const GetRateByIdUseCase({
    required RateRepository repository,
    required ValidateRateAssetsService validateRateAssets,
  }) : _repository = repository, // ignore: prefer_initializing_formals
       _validateRateAssets = // ignore: prefer_initializing_formals
           validateRateAssets;

  final RateRepository _repository;
  final ValidateRateAssetsService _validateRateAssets;

  /// Retrieves the persisted rate identified by [id].
  ///
  /// Asset-reference validation failures are returned unchanged.
  Future<Result<Rate, BaseFailure>> call(RateId id) async {
    final rateResult = await _repository.getById(id);

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
