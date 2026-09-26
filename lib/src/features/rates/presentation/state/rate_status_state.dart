import 'package:axiom/src/application/failures/invalid_valuation_currency_failure.dart';
import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/di/get_asset_by_code_use_case_provider.dart';
import 'package:axiom/src/features/assets/di/get_asset_use_case_provider.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/assets/domain/failures/asset_not_found_failure.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_code.dart';
import 'package:axiom/src/features/rates/di/get_latest_rate_for_pair_use_case_provider.dart';
import 'package:axiom/src/features/rates/domain/entities/rate.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'rate_status_state.g.dart';

/// One persisted-rate status row.
final class RateStatusItem {
  /// Creates a rate-status row.
  const RateStatusItem({required this.asset, required this.latestRate});

  final Asset asset;
  final Rate? latestRate;

  bool get hasRate => latestRate != null;
}

/// Complete rate-status presentation data.
final class RateStatusData {
  /// Creates rate-status data.
  const RateStatusData({required this.quoteCurrency, required this.items});

  /// Canonical persisted-rate quote currency.
  final Currency quoteCurrency;

  /// Assets requiring an observation against [quoteCurrency].
  final List<RateStatusItem> items;
}

/// Loads the latest persisted USD observation for each non-USD asset.
///
/// No arbitrary age threshold is applied. The UI exposes the observation's
/// actual financial timestamp so freshness policy remains explicit rather than
/// guessed by presentation code.
@riverpod
Future<Result<RateStatusData, BaseFailure>> rateStatus(Ref ref) async {
  final usdResult = await ref.watch(getAssetByCodeUseCaseProvider)(
    AssetCode('USD'),
  );

  if (usdResult case final Failure<BaseFailure> failure) {
    return failure;
  }

  final usdAsset = usdResult.valueOrNull;

  if (usdAsset == null) {
    return AssetNotFoundFailure(message: 'USD asset is not configured.');
  }

  if (usdAsset is! Currency) {
    return InvalidValuationCurrencyFailure(
      message:
          'The canonical persisted-rate quote asset USD must be a Currency.',
    );
  }

  final assetsResult = await ref.watch(getAssetUseCaseProvider)();

  if (assetsResult case final Failure<BaseFailure> failure) {
    return failure;
  }

  final assets = List<Asset>.of(assetsResult.valueOrNull!)
    ..sort((left, right) => left.code.value.compareTo(right.code.value));

  final items = <RateStatusItem>[];
  final getLatest = ref.watch(getLatestRateForPairUseCaseProvider);

  for (final asset in assets) {
    if (asset.id == usdAsset.id) {
      continue;
    }

    final latestResult = await getLatest(
      baseAssetId: asset.id,
      quoteAssetId: usdAsset.id,
    );

    if (latestResult case final Failure<BaseFailure> failure) {
      return failure;
    }

    items.add(
      RateStatusItem(asset: asset, latestRate: latestResult.valueOrNull),
    );
  }

  return Success(
    RateStatusData(quoteCurrency: usdAsset, items: List.unmodifiable(items)),
  );
}
