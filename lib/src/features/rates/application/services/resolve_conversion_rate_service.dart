import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/failures/record_not_found_failure.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/rates/application/use_cases/get_rate_at_use_case.dart';
import 'package:axiom/src/features/rates/domain/services/rate_conversion_service.dart';
import 'package:decimal/decimal.dart';

/// Resolves the conversion rate between two assets at a point in time.
///
/// Resolution follows these rules:
///
/// 1. Converting an asset to itself resolves to `1`.
/// 2. The direct rate is attempted first.
/// 3. If the direct rate does not exist, the reverse rate is attempted
///    and inverted.
/// 4. Other failures are propagated unchanged.
final class ResolveConversionRateService {
  /// Creates a conversion-rate resolver.
  const ResolveConversionRateService({
    required GetRateAtUseCase getRateAt,
    required RateConversionService rateConversion,
  }) : _getRateAt = getRateAt, // ignore: prefer_initializing_formals
       _rateConversion = rateConversion; // ignore: prefer_initializing_formals

  final GetRateAtUseCase _getRateAt;
  final RateConversionService _rateConversion;

  /// Resolves the number of [toAssetId] units per one [fromAssetId] unit.
  Future<Result<Decimal, BaseFailure>> call({
    required AssetId fromAssetId,
    required AssetId toAssetId,
    required DateTime at,
  }) async {
    if (fromAssetId == toAssetId) {
      return Success(Decimal.one);
    }

    final directResult = await _getRateAt(
      baseAssetId: fromAssetId,
      quoteAssetId: toAssetId,
      at: at,
    );

    return directResult.when<Future<Result<Decimal, BaseFailure>>>(
      success: (directRate) async => Success(directRate.rate),
      failure: (failure) async {
        if (failure is! RecordNotFoundFailure) {
          return failure;
        }

        final reverseResult = await _getRateAt(
          baseAssetId: toAssetId,
          quoteAssetId: fromAssetId,
          at: at,
        );

        return reverseResult.when<Result<Decimal, BaseFailure>>(
          success: (reverseRate) {
            return Success(_rateConversion.invert(reverseRate));
          },
          failure: (failure) => failure,
        );
      },
    );
  }
}
