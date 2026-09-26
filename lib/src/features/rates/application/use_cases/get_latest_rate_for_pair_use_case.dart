import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/rates/domain/entities/rate.dart';
import 'package:axiom/src/features/rates/domain/failures/rate_failure.dart';
import 'package:axiom/src/features/rates/domain/failures/rate_not_found_failure.dart';
import 'package:axiom/src/features/rates/domain/repositories/rate_repository.dart';

/// Retrieves the financially latest persisted rate for one exact pair.
///
/// "Latest" is determined exclusively by [Rate.effectiveAt] through the
/// repository contract.
///
/// Missing rate data is represented as a successful `null`, because absence is
/// a normal state for status presentation rather than an operational failure.
final class GetLatestRateForPairUseCase {
  /// Creates the use case.
  const GetLatestRateForPairUseCase(this._repository);

  final RateRepository _repository;

  /// Returns the latest exact-pair observation, or `null` when none exists.
  Future<Result<Rate?, RateFailure>> call({
    required AssetId baseAssetId,
    required AssetId quoteAssetId,
  }) async {
    final result = await _repository.getLatestByPair(
      baseAssetId: baseAssetId,
      quoteAssetId: quoteAssetId,
    );

    return result.when<Result<Rate?, RateFailure>>(
      success: (rate) => Success<Rate?>(rate),
      failure: (failure) {
        if (failure is RateNotFoundFailure) {
          return const Success<Rate?>(null);
        }

        return failure;
      },
    );
  }
}
