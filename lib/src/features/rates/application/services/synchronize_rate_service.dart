import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/ports/clock/clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/application/use_cases/get_assets_by_ids_use_case.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/assets/domain/failures/referenced_asset_not_found_failure.dart';
import 'package:axiom/src/features/rates/application/failures/invalid_rate_asset_semantics_failure.dart';
import 'package:axiom/src/features/rates/application/failures/rate_synchronization_conflict_failure.dart';
import 'package:axiom/src/features/rates/application/models/rate_cache_entry.dart';
import 'package:axiom/src/features/rates/application/models/rate_source_observation.dart';
import 'package:axiom/src/features/rates/application/policies/rate_refresh_policy.dart';
import 'package:axiom/src/features/rates/application/ports/exchange_rate_source_adapter.dart';
import 'package:axiom/src/features/rates/application/ports/latest_rate_cache.dart';
import 'package:axiom/src/features/rates/application/ports/market_price_source_adapter.dart';
import 'package:axiom/src/features/rates/domain/entities/rate.dart';
import 'package:axiom/src/features/rates/domain/failures/rate_not_found_failure.dart';
import 'package:axiom/src/features/rates/domain/repositories/rate_repository.dart';

/// Synchronizes the latest persisted rate for one asset.
///
/// Persisted rates use the configured canonical bridge asset as their quote
/// asset. Under the current configuration this is USD.
///
/// ## Source selection
///
/// Currency assets use [ExchangeRateSourceAdapter].
///
/// Crypto, stock, and commodity assets use [MarketPriceSourceAdapter].
///
/// ## Persisted rate types
///
/// Currency/Currency observations become [ExchangeRate] entities.
///
/// Market-priced non-currency/Currency observations become [MarketPriceRate]
/// entities.
///
/// ## Financial semantics
///
/// [Rate.effectiveAt] determines observation ordering.
///
/// Audit timestamps and cache timestamps do not determine financial ordering.
///
/// Older source observations cannot replace newer persisted observations.
///
/// Equal timestamp/equal value is idempotent.
///
/// Equal timestamp/different value is a synchronization conflict.
final class SynchronizeRateService {
  final RateRepository _repository;
  final GetAssetsByIdsUseCase _getAssetsByIds;
  final ExchangeRateSourceAdapter _exchangeRateSource;
  final MarketPriceSourceAdapter _marketPriceSource;
  final LatestRateCache _cache;
  final RateRefreshPolicy _refreshPolicy;
  final AssetId _canonicalBridgeAssetId;
  final Clock _clock;

  /// Creates the synchronization service.
  SynchronizeRateService({
    required RateRepository repository,
    required GetAssetsByIdsUseCase getAssetsByIds,
    required ExchangeRateSourceAdapter exchangeRateSource,
    required MarketPriceSourceAdapter marketPriceSource,
    required LatestRateCache cache,
    required RateRefreshPolicy refreshPolicy,
    required AssetId canonicalBridgeAssetId,
    required Clock clock,
  }) : _repository = repository, // ignore: prefer_initializing_formals
       _getAssetsByIds = // ignore: prefer_initializing_formals
           getAssetsByIds,
       _exchangeRateSource = // ignore: prefer_initializing_formals
           exchangeRateSource,
       _marketPriceSource = // ignore: prefer_initializing_formals
           marketPriceSource,
       _cache = cache, // ignore: prefer_initializing_formals
       _refreshPolicy = // ignore: prefer_initializing_formals
           refreshPolicy,
       _canonicalBridgeAssetId = // ignore: prefer_initializing_formals
           canonicalBridgeAssetId,
       _clock = clock; // ignore: prefer_initializing_formals

  /// Synchronizes the latest persisted rate for [baseAssetId].
  Future<Result<Rate, BaseFailure>> call({
    required AssetId baseAssetId,
    bool forceRefresh = false,
  }) async {
    if (baseAssetId == _canonicalBridgeAssetId) {
      throw ArgumentError.value(
        baseAssetId,
        'baseAssetId',
        'The synchronization base asset cannot equal the canonical quote asset.',
      );
    }

    final cachedEntry = _cache.getLatest(
      baseAssetId: baseAssetId,
      quoteAssetId: _canonicalBridgeAssetId,
    );

    final shouldRefresh = _refreshPolicy.shouldRefresh(
      entry: cachedEntry,
      now: _clock.nowUtc,
      forceRefresh: forceRefresh,
    );

    if (!shouldRefresh) {
      return Success(cachedEntry!.rate);
    }

    final pairResult = await _loadPair(baseAssetId);

    return pairResult.when<Future<Result<Rate, BaseFailure>>>(
      success: (pair) async {
        final sourceResult = await _fetchLatest(
          baseAsset: pair.base,
          quoteCurrency: pair.quote,
        );

        return sourceResult.when<Future<Result<Rate, BaseFailure>>>(
          success: (observation) => _synchronizeObservation(
            baseAsset: pair.base,
            quoteCurrency: pair.quote,
            observation: observation,
          ),
          failure: (failure) async => failure,
        );
      },
      failure: (failure) async => failure,
    );
  }

  Future<Result<({Asset base, Currency quote}), BaseFailure>> _loadPair(
    AssetId baseAssetId,
  ) async {
    final result = await _getAssetsByIds([
      baseAssetId,
      _canonicalBridgeAssetId,
    ]);

    return result.when<Result<({Asset base, Currency quote}), BaseFailure>>(
      success: (lookup) {
        if (lookup.missing.isNotEmpty) {
          return ReferencedAssetNotFoundFailure(
            message:
                'Rate synchronization asset was not found: '
                '${lookup.missing.first.value}',
          );
        }

        Asset? baseAsset;
        Asset? quoteAsset;

        for (final asset in lookup.found) {
          if (asset.id == baseAssetId) {
            baseAsset = asset;
          }

          if (asset.id == _canonicalBridgeAssetId) {
            quoteAsset = asset;
          }
        }

        if (baseAsset == null) {
          return ReferencedAssetNotFoundFailure(
            message:
                'Rate synchronization base asset was not found: '
                '${baseAssetId.value}',
          );
        }

        if (quoteAsset == null) {
          return ReferencedAssetNotFoundFailure(
            message:
                'Canonical rate quote asset was not found: '
                '${_canonicalBridgeAssetId.value}',
          );
        }

        if (quoteAsset is! Currency) {
          return InvalidRateAssetSemanticsFailure(
            message:
                'Canonical persisted-rate quote asset must be a Currency: '
                '${quoteAsset.id.value}.',
          );
        }

        return Success((base: baseAsset, quote: quoteAsset));
      },
      failure: (failure) => failure,
    );
  }

  Future<Result<RateSourceObservation, BaseFailure>> _fetchLatest({
    required Asset baseAsset,
    required Currency quoteCurrency,
  }) {
    return switch (baseAsset) {
      Currency() => _exchangeRateSource.fetchLatest(
        baseCurrency: baseAsset,
        quoteCurrency: quoteCurrency,
      ),
      CryptoAsset() ||
      StockAsset() ||
      CommodityAsset() => _marketPriceSource.fetchLatest(
        baseAsset: baseAsset,
        quoteCurrency: quoteCurrency,
      ),
    };
  }

  Future<Result<Rate, BaseFailure>> _synchronizeObservation({
    required Asset baseAsset,
    required Currency quoteCurrency,
    required RateSourceObservation observation,
  }) async {
    final latestResult = await _repository.getLatestByPair(
      baseAssetId: baseAsset.id,
      quoteAssetId: quoteCurrency.id,
    );

    return latestResult.when<Future<Result<Rate, BaseFailure>>>(
      success: (latest) => _synchronizeAgainstExisting(
        latest: latest,
        baseAsset: baseAsset,
        quoteCurrency: quoteCurrency,
        observation: observation,
      ),
      failure: (failure) {
        if (failure is RateNotFoundFailure) {
          return _createObservation(
            baseAsset: baseAsset,
            quoteCurrency: quoteCurrency,
            observation: observation,
          );
        }

        return Future.value(failure);
      },
    );
  }

  Future<Result<Rate, BaseFailure>> _synchronizeAgainstExisting({
    required Rate latest,
    required Asset baseAsset,
    required Currency quoteCurrency,
    required RateSourceObservation observation,
  }) async {
    final typeFailure = _validateExistingRateType(
      baseAsset: baseAsset,
      latest: latest,
    );

    if (typeFailure != null) {
      return typeFailure;
    }

    if (observation.effectiveAt.isBefore(latest.effectiveAt)) {
      _cacheRate(latest);

      return Success(latest);
    }

    if (observation.effectiveAt.isAtSameMomentAs(latest.effectiveAt)) {
      if (observation.rate != latest.rate) {
        return RateSynchronizationConflictFailure(
          message:
              'Rate source returned a different value for the existing '
              'observation at ${latest.effectiveAt.toIso8601String()}.',
        );
      }

      _cacheRate(latest);

      return Success(latest);
    }

    return _createObservation(
      baseAsset: baseAsset,
      quoteCurrency: quoteCurrency,
      observation: observation,
    );
  }

  Future<Result<Rate, BaseFailure>> _createObservation({
    required Asset baseAsset,
    required Currency quoteCurrency,
    required RateSourceObservation observation,
  }) async {
    final Rate rate = switch (baseAsset) {
      Currency() => ExchangeRate.create(
        baseAssetId: baseAsset.id,
        quoteAssetId: quoteCurrency.id,
        rate: observation.rate,
        effectiveAt: observation.effectiveAt,
        clock: _clock,
      ),
      CryptoAsset() ||
      StockAsset() ||
      CommodityAsset() => MarketPriceRate.create(
        baseAssetId: baseAsset.id,
        quoteAssetId: quoteCurrency.id,
        rate: observation.rate,
        effectiveAt: observation.effectiveAt,
        clock: _clock,
      ),
    };

    final createResult = await _repository.create(rate);

    return createResult.when<Result<Rate, BaseFailure>>(
      success: (_) {
        _cacheRate(rate);

        return Success(rate);
      },
      failure: (failure) => failure,
    );
  }

  InvalidRateAssetSemanticsFailure? _validateExistingRateType({
    required Asset baseAsset,
    required Rate latest,
  }) {
    if (baseAsset is Currency) {
      if (latest is! ExchangeRate) {
        return InvalidRateAssetSemanticsFailure(
          message:
              'Currency asset ${baseAsset.id.value} has a persisted '
              'non-exchange rate.',
        );
      }

      return null;
    }

    if (latest is! MarketPriceRate) {
      return InvalidRateAssetSemanticsFailure(
        message:
            'Market-priced asset ${baseAsset.id.value} has a persisted '
            'non-market-price rate.',
      );
    }

    return null;
  }

  void _cacheRate(Rate rate) {
    _cache.put(RateCacheEntry(rate: rate, cachedAt: _clock.nowUtc));
  }
}
