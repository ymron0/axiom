import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/ports/clock/clock.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/application/use_cases/get_assets_by_ids_use_case.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/assets/domain/failures/referenced_asset_not_found_failure.dart';
import 'package:axiom/src/features/rates/application/failures/rate_synchronization_conflict_failure.dart';
import 'package:axiom/src/features/rates/application/failures/unsupported_rate_synchronization_asset_failure.dart';
import 'package:axiom/src/features/rates/application/models/rate_cache_entry.dart';
import 'package:axiom/src/features/rates/application/models/rate_source_observation.dart';
import 'package:axiom/src/features/rates/application/policies/rate_refresh_policy.dart';
import 'package:axiom/src/features/rates/application/ports/exchange_rate_source_adapter.dart';
import 'package:axiom/src/features/rates/application/ports/latest_rate_cache.dart';
import 'package:axiom/src/features/rates/domain/entities/exchange_rate.dart';
import 'package:axiom/src/features/rates/domain/entities/rate.dart';
import 'package:axiom/src/features/rates/domain/failures/rate_not_found_failure.dart';
import 'package:axiom/src/features/rates/domain/repositories/rate_repository.dart';

/// Synchronizes the latest persisted exchange rate for one base currency.
///
/// Persisted rates always use the configured canonical bridge asset as quote
/// asset. With the current configuration this is USD.
///
/// ## Workflow
///
/// 1. Check the latest-rate cache.
/// 2. Return it immediately when the refresh policy says it is fresh.
/// 3. Resolve the requested base asset and canonical quote asset.
/// 4. Require both assets to be [Currency] instances.
/// 5. Request a normalized observation from the external adapter.
/// 6. Compare it with the latest persisted observation.
/// 7. Persist only a genuinely newer observation.
/// 8. Update the latest-rate cache only after persistence succeeds.
///
/// ## Financial semantics
///
/// `Rate.effectiveAt` determines whether an observation is newer.
///
/// `Rate.createdAt`, `Rate.modifiedAt`, and cache time never determine market
/// ordering.
///
/// A source observation older than the already-persisted rate must never
/// replace or downgrade the persisted latest rate.
///
/// A source observation having the same effective timestamp and same value is
/// treated as an idempotent synchronization.
///
/// A source observation having the same timestamp but a different value
/// returns [RateSynchronizationConflictFailure].
///
/// ## Failure semantics
///
/// Source, asset-repository, and rate-repository failures are propagated
/// unchanged where possible.
///
/// A stale cache is not silently returned after a source failure. Doing so
/// would disguise failed synchronization as successful fresh data.
final class SynchronizeRateService {
  final RateRepository _repository;
  final GetAssetsByIdsUseCase _getAssetsByIds;
  final ExchangeRateSourceAdapter _source;
  final LatestRateCache _cache;
  final RateRefreshPolicy _refreshPolicy;
  final AssetId _canonicalBridgeAssetId;
  final Clock _clock;

  /// Creates the synchronization service.
  SynchronizeRateService({
    required RateRepository repository,
    required GetAssetsByIdsUseCase getAssetsByIds,
    required ExchangeRateSourceAdapter source,
    required LatestRateCache cache,
    required RateRefreshPolicy refreshPolicy,
    required AssetId canonicalBridgeAssetId,
    required Clock clock,
  }) : _repository = repository, // ignore: prefer_initializing_formals
       _getAssetsByIds = // ignore: prefer_initializing_formals
           getAssetsByIds,
       _source = source, // ignore: prefer_initializing_formals
       _cache = cache, // ignore: prefer_initializing_formals
       _refreshPolicy = // ignore: prefer_initializing_formals
           refreshPolicy,
       _canonicalBridgeAssetId = // ignore: prefer_initializing_formals
           canonicalBridgeAssetId,
       _clock = clock; // ignore: prefer_initializing_formals

  /// Synchronizes the latest persisted rate for [baseAssetId].
  ///
  /// The quote asset is always the injected canonical bridge asset.
  ///
  /// Set [forceRefresh] to bypass a fresh cache entry. Persistence remains
  /// idempotent even during a forced refresh.
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

    final currenciesResult = await _loadCurrencies(baseAssetId);

    return currenciesResult.when<Future<Result<Rate, BaseFailure>>>(
      success: (pair) async {
        final sourceResult = await _source.fetchLatest(
          baseCurrency: pair.base,
          quoteCurrency: pair.quote,
        );

        return sourceResult.when<Future<Result<Rate, BaseFailure>>>(
          success: (observation) =>
              _synchronizeObservation(pair: pair, observation: observation),
          failure: (failure) async => failure,
        );
      },
      failure: (failure) async => failure,
    );
  }

  Future<Result<_CurrencyPair, BaseFailure>> _loadCurrencies(
    AssetId baseAssetId,
  ) async {
    final assetsResult = await _getAssetsByIds([
      baseAssetId,
      _canonicalBridgeAssetId,
    ]);

    return assetsResult.when<Result<_CurrencyPair, BaseFailure>>(
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

        // Asset is sealed and currently permits only Currency. Remove this
        // exclusion and add a test when another Asset subtype is introduced.
        // coverage:ignore-start
        if (baseAsset is! Currency) {
          return UnsupportedRateSynchronizationAssetFailure(
            message:
                'Exchange-rate base asset must be a currency: '
                '${baseAsset.id.value}',
          );
        }

        if (quoteAsset is! Currency) {
          return UnsupportedRateSynchronizationAssetFailure(
            message:
                'Exchange-rate quote asset must be a currency: '
                '${quoteAsset.id.value}',
          );
        }
        // coverage:ignore-end

        return Success(_CurrencyPair(base: baseAsset, quote: quoteAsset));
      },
      failure: (failure) => failure,
    );
  }

  Future<Result<Rate, BaseFailure>> _synchronizeObservation({
    required _CurrencyPair pair,
    required RateSourceObservation observation,
  }) async {
    final latestResult = await _repository.getLatestByPair(
      baseAssetId: pair.base.id,
      quoteAssetId: pair.quote.id,
    );

    return latestResult.when<Future<Result<Rate, BaseFailure>>>(
      success: (latest) => _synchronizeAgainstExisting(
        latest: latest,
        pair: pair,
        observation: observation,
      ),
      failure: (failure) {
        if (failure is RateNotFoundFailure) {
          return _createObservation(pair: pair, observation: observation);
        }

        return Future.value(failure);
      },
    );
  }

  Future<Result<Rate, BaseFailure>> _synchronizeAgainstExisting({
    required Rate latest,
    required _CurrencyPair pair,
    required RateSourceObservation observation,
  }) async {
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

    return _createObservation(pair: pair, observation: observation);
  }

  Future<Result<Rate, BaseFailure>> _createObservation({
    required _CurrencyPair pair,
    required RateSourceObservation observation,
  }) async {
    final rate = ExchangeRate.create(
      baseAssetId: pair.base.id,
      quoteAssetId: pair.quote.id,
      rate: observation.rate,
      effectiveAt: observation.effectiveAt,
      clock: _clock,
    );

    final createResult = await _repository.create(rate);

    return createResult.when<Result<Rate, BaseFailure>>(
      success: (_) {
        _cacheRate(rate);

        return Success(rate);
      },
      failure: (failure) => failure,
    );
  }

  void _cacheRate(Rate rate) {
    _cache.put(RateCacheEntry(rate: rate, cachedAt: _clock.nowUtc));
  }
}

final class _CurrencyPair {
  final Currency base;
  final Currency quote;

  const _CurrencyPair({required this.base, required this.quote});
}
