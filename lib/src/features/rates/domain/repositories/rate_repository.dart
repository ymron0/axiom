// coverage:ignore-file

import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/failures/record_already_exists_failure.dart';
import 'package:axiom/src/core/failures/record_not_found_failure.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/rate_id.dart';
import 'package:axiom/src/core/repositories/batch_lookup.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/rates/domain/entities/rate.dart';

/// Domain-facing repository contract for storing and resolving [Rate] entities.
///
/// Implementations may use in-memory storage, a database, files, remote-backed
/// caches, or another persistence mechanism. Consumers of this interface must
/// not depend on those implementation details.
///
/// Persisted rates must always use USD as their quote asset.
///
/// This restriction applies only to repository writes. [Rate] itself may
/// represent any base/quote pair, including rates calculated at runtime.
/// It is the responsibility of the use case to ensure that quoted rate pairs
/// conform to this restriction.
///
/// ## Pair semantics
///
/// Rate pairs are ordered.
///
/// A lookup with:
///
/// ```text
/// baseAssetId  = BTC
/// quoteAssetId = USD
/// ```
///
/// searches only for rates whose meaning is:
///
/// ```text
/// 1 BTC = rate × USD
/// ```
///
/// The repository must never implicitly reverse a pair or calculate a
/// reciprocal rate. Consequently, BTC/USD and USD/BTC are distinct lookup
/// keys.
///
/// The terms "base" and "quote" are financial pair terminology and are
/// unrelated to the application's configured valuation currency.
///
/// ## Temporal semantics
///
/// [Rate.effectiveAt] determines when a rate is financially applicable.
///
/// Temporal comparisons are instant-based. Implementations must compare
/// timestamps consistently in UTC, regardless of the timezone representation
/// supplied by callers.
///
/// [getAtOrBefore] implements as-of lookup semantics: it returns the rate with
/// the greatest [Rate.effectiveAt] that is less than or equal to the requested
/// instant.
///
/// It must never return a later rate.
///
/// [getLatestByPair] returns the rate having the greatest
/// [Rate.effectiveAt] for the requested ordered pair.
///
/// ## Missing-rate semantics
///
/// Single-result operations such as [getById], [getLatestByPair], and
/// [getAtOrBefore] return a [RecordNotFoundFailure] when no matching rate
/// exists.
///
/// Collection queries such as [getByPair] do not treat an empty result as a
/// failure. When no observations exist for the requested pair, they return a
/// successful empty list.
///
/// Batch identity lookup uses [BatchLookup] so that found and missing IDs are
/// represented explicitly rather than failing the whole lookup because one or
/// more requested IDs are absent.
///
/// ## Batch semantics
///
/// [createAll] and [updateAll] are atomic.
///
/// If any item in a batch cannot be created or updated, the operation must
/// fail without applying any item in that batch.
///
/// [getByIds] is not atomic in that sense: it returns the successfully resolved
/// records together with the requested IDs that were not found.
///
/// ## Contract
///
/// Implementations must:
///
/// - preserve all [Rate] domain invariants;
/// - preserve exact base/quote orientation;
/// - use [Rate.effectiveAt] for temporal lookup;
/// - provide deterministic temporal ordering;
/// - use the standard domain [Result] and failure types;
/// - expose no persistence-specific objects through this interface.
///
/// Repository implementations are validated through repository contract tests.
/// The abstract interface itself does not require artificial unit tests.
abstract interface class RateRepository {
  /// Stores [rate].
  ///
  /// The caller must ensure that the quote asset is USD.
  ///
  /// Returns [RecordAlreadyExistsFailure] when a rate with the same [RateId]
  /// already exists.
  ///
  /// Other storage-independent failures are represented by [BaseFailure].
  Future<Result<void, BaseFailure>> create(Rate rate);

  /// Atomically stores every rate in [rates].
  ///
  /// The caller must ensure that the quote asset is USD.
  ///
  /// If any rate cannot be created, no rate from the batch may be persisted.
  ///
  /// Returns [RecordAlreadyExistsFailure] when any supplied [RateId] already
  /// exists.
  Future<Result<void, BaseFailure>> createAll(List<Rate> rates);

  /// Returns the rate identified by [id].
  ///
  /// Returns [RecordNotFoundFailure] when no rate exists for [id].
  Future<Result<Rate, BaseFailure>> getById(RateId id);

  /// Resolves multiple rates by identity.
  ///
  /// Found and missing identifiers are represented independently through
  /// [BatchLookup]. A missing individual ID therefore does not cause the
  /// entire lookup to fail.
  Future<Result<BatchLookup<Rate, RateId>, BaseFailure>> getByIds(
    List<RateId> ids,
  );

  /// Returns all stored observations for the exact ordered asset pair.
  ///
  /// Only rates satisfying:
  ///
  /// ```text
  /// rate.baseAssetId  == baseAssetId
  /// rate.quoteAssetId == quoteAssetId
  /// ```
  ///
  /// are returned.
  ///
  /// The repository must not search the inverse pair.
  ///
  /// Results are ordered by [Rate.effectiveAt] ascending, from oldest to
  /// newest.
  ///
  /// Returns an empty list when no observations exist for the pair.
  Future<Result<List<Rate>, BaseFailure>> getByPair({
    required AssetId baseAssetId,
    required AssetId quoteAssetId,
  });

  /// Returns the most recent stored rate for the exact ordered asset pair.
  ///
  /// "Latest" refers exclusively to the greatest [Rate.effectiveAt]. It does
  /// not refer to [Rate.createdAt] or [Rate.modifiedAt].
  ///
  /// The repository must not search or invert the opposite pair.
  ///
  /// Returns [RecordNotFoundFailure] when the pair has no stored rates.
  Future<Result<Rate, BaseFailure>> getLatestByPair({
    required AssetId baseAssetId,
    required AssetId quoteAssetId,
  });

  /// Returns the rate applicable to the exact ordered pair at or immediately
  /// before [effectiveAt].
  ///
  /// The result is the matching rate having the greatest effective timestamp
  /// satisfying:
  ///
  /// ```text
  /// rate.effectiveAt <= effectiveAt
  /// ```
  ///
  /// For example, if rates exist at:
  ///
  /// ```text
  /// 2026-09-09 00:00 UTC
  /// 2026-09-10 00:00 UTC
  /// ```
  ///
  /// and [effectiveAt] is:
  ///
  /// ```text
  /// 2026-09-10 14:30 UTC
  /// ```
  ///
  /// the observation from `2026-09-10 00:00 UTC` is returned.
  ///
  /// A rate whose effective timestamp is later than the requested instant must
  /// never be returned.
  ///
  /// Returns [RecordNotFoundFailure] when no rate exists for the pair at or
  /// before the requested instant.
  Future<Result<Rate, BaseFailure>> getAtOrBefore({
    required AssetId baseAssetId,
    required AssetId quoteAssetId,
    required DateTime effectiveAt,
  });
}
