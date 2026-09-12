import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/failures/record_not_found_failure.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/application/use_cases/get_assets_by_ids_use_case.dart';
import 'package:axiom/src/features/rates/domain/entities/exchange_rate.dart';
import 'package:axiom/src/features/rates/domain/entities/rate.dart';

/// Validates that assets referenced by rates exist.
///
/// The service resolves referenced assets through the Assets application
/// boundary.
final class ValidateRateAssetsService {
  /// Creates a validator backed by [getAssetsByIds].
  const ValidateRateAssetsService({
    required GetAssetsByIdsUseCase getAssetsByIds,
  }) : _getAssetsByIds = getAssetsByIds; // ignore: prefer_initializing_formals

  final GetAssetsByIdsUseCase _getAssetsByIds;

  /// Validates the referenced assets of every supplied rate.
  ///
  /// Returns [RecordNotFoundFailure] when a referenced asset does not exist.
  Future<Result<void, BaseFailure>> call(Iterable<Rate> rates) async {
    final exchangeRates = rates.whereType<ExchangeRate>().toList();
    if (exchangeRates.isEmpty) {
      return const Success(null);
    }

    final referencedIds = <AssetId>{
      for (final rate in exchangeRates) ...[
        rate.baseAssetId,
        rate.quoteAssetId,
      ],
    }.toList();
    final assetsResult = await _getAssetsByIds(referencedIds);

    return assetsResult.when<Result<void, BaseFailure>>(
      success: (lookup) {
        if (lookup.missing.isNotEmpty) {
          return RecordNotFoundFailure(
            message:
                'Referenced rate asset was not found: '
                '${lookup.missing.first.value}',
          );
        }

        return const Success(null);
      },
      failure: (failure) => failure,
    );
  }
}
