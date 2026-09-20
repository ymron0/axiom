import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/application/use_cases/get_assets_by_ids_use_case.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/assets/domain/failures/referenced_asset_not_found_failure.dart';
import 'package:axiom/src/features/rates/application/failures/invalid_rate_asset_semantics_failure.dart';
import 'package:axiom/src/features/rates/domain/entities/rate.dart';

/// Validates the Assets referenced by persisted or newly-created Rates.
///
/// Validation includes both referential integrity and financial asset-type
/// semantics.
///
/// ## Supported relationships
///
/// ExchangeRate:
///
/// ```text
/// Currency / Currency
/// ```
///
/// MarketPriceRate:
///
/// ```text
/// CryptoAsset    / Currency
/// StockAsset     / Currency
/// CommodityAsset / Currency
/// ```
final class ValidateRateAssetsService {
  final GetAssetsByIdsUseCase _getAssetsByIds;

  /// Creates a validator backed by [getAssetsByIds].
  const ValidateRateAssetsService({
    required GetAssetsByIdsUseCase getAssetsByIds,
  }) : _getAssetsByIds = getAssetsByIds; // ignore: prefer_initializing_formals

  /// Validates all referenced assets and rate-type relationships.
  Future<Result<void, BaseFailure>> call(Iterable<Rate> rates) async {
    final rateList = List<Rate>.unmodifiable(rates);

    if (rateList.isEmpty) {
      return const Success(null);
    }

    final referencedIds = <AssetId>{
      for (final rate in rateList) ...[rate.baseAssetId, rate.quoteAssetId],
    }.toList(growable: false);

    final assetsResult = await _getAssetsByIds(referencedIds);

    return assetsResult.when<Result<void, BaseFailure>>(
      success: (lookup) {
        if (lookup.missing.isNotEmpty) {
          return ReferencedAssetNotFoundFailure(
            message:
                'Referenced rate asset was not found: '
                '${lookup.missing.first.value}',
          );
        }

        final assetsById = <AssetId, Asset>{
          for (final asset in lookup.found) asset.id: asset,
        };

        for (final rate in rateList) {
          final baseAsset = assetsById[rate.baseAssetId];
          final quoteAsset = assetsById[rate.quoteAssetId];

          if (baseAsset == null) {
            return ReferencedAssetNotFoundFailure(
              message:
                  'Referenced rate base asset was not found: '
                  '${rate.baseAssetId.value}',
            );
          }

          if (quoteAsset == null) {
            return ReferencedAssetNotFoundFailure(
              message:
                  'Referenced rate quote asset was not found: '
                  '${rate.quoteAssetId.value}',
            );
          }

          final semanticsFailure = switch (rate) {
            ExchangeRate() => _validateExchangeRate(
              baseAsset: baseAsset,
              quoteAsset: quoteAsset,
            ),
            MarketPriceRate() => _validateMarketPriceRate(
              baseAsset: baseAsset,
              quoteAsset: quoteAsset,
            ),
          };

          if (semanticsFailure != null) {
            return semanticsFailure;
          }
        }

        return const Success(null);
      },
      failure: (failure) => failure,
    );
  }

  static InvalidRateAssetSemanticsFailure? _validateExchangeRate({
    required Asset baseAsset,
    required Asset quoteAsset,
  }) {
    if (baseAsset is! Currency) {
      return InvalidRateAssetSemanticsFailure(
        message:
            'Exchange-rate base asset must be a Currency: '
            '${baseAsset.id.value}.',
      );
    }

    if (quoteAsset is! Currency) {
      return InvalidRateAssetSemanticsFailure(
        message:
            'Exchange-rate quote asset must be a Currency: '
            '${quoteAsset.id.value}.',
      );
    }

    return null;
  }

  static InvalidRateAssetSemanticsFailure? _validateMarketPriceRate({
    required Asset baseAsset,
    required Asset quoteAsset,
  }) {
    final supportedBase =
        baseAsset is CryptoAsset ||
        baseAsset is StockAsset ||
        baseAsset is CommodityAsset;

    if (!supportedBase) {
      return InvalidRateAssetSemanticsFailure(
        message:
            'Market-price base asset must be a market-priced non-currency '
            'asset: ${baseAsset.id.value}.',
      );
    }

    if (quoteAsset is! Currency) {
      return InvalidRateAssetSemanticsFailure(
        message:
            'Market-price quote asset must be a Currency: '
            '${quoteAsset.id.value}.',
      );
    }

    return null;
  }
}
