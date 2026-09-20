import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/identity/ids/rate_id.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record.dart';
import 'package:axiom/src/core/persistence/persistence_operation_guard.dart';
import 'package:axiom/src/core/persistence/sembast_stores.dart';
import 'package:axiom/src/core/repositories/batch_lookup.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/rates/data/models/rate_persistence_model.dart';
import 'package:axiom/src/features/rates/domain/entities/rate.dart';
import 'package:axiom/src/features/rates/domain/failures/rate_already_exists_failure.dart';
import 'package:axiom/src/features/rates/domain/failures/rate_failure.dart';
import 'package:axiom/src/features/rates/domain/failures/rate_not_found_failure.dart';
import 'package:axiom/src/features/rates/domain/failures/rate_repository_failure.dart';
import 'package:axiom/src/features/rates/domain/repositories/rate_repository.dart';
import 'package:sembast/sembast.dart';

/// Persists rate observations in the Sembast rates store.
///
/// The repository implements the domain-level [RateRepository] contract while
/// keeping Sembast-specific persistence details inside the data layer.
///
/// Rate IDs are used as Sembast record keys.
///
/// Base and quote asset IDs remain persisted fields because the ordered asset
/// pair is independently queryable.
///
/// ## Pair semantics
///
/// Rate pairs are always treated as ordered.
///
/// A query for:
///
/// ```text
/// baseAssetId  = EUR
/// quoteAssetId = USD
/// ```
///
/// searches only EUR/USD observations. It never searches USD/EUR and never
/// calculates an inverse rate.
///
/// ## Temporal semantics
///
/// [Rate.effectiveAt] is the only timestamp used to determine financial
/// ordering.
///
/// Pair observations are reconstructed into domain entities before temporal
/// ordering is performed. This avoids coupling domain ordering semantics to
/// the textual representation used to persist timestamps.
///
/// When two observations have the same [Rate.effectiveAt], their [Rate.id] is
/// used as a deterministic secondary ordering key.
///
/// ## Atomicity
///
/// [createAll] performs all validation and writes inside one Sembast
/// transaction. If any requested identity already exists or a write fails,
/// none of the requested records is committed.
///
/// ## Failure translation
///
/// Expected persistence exceptions are translated into
/// [RateRepositoryFailure] by [guardPersistenceOperation].
///
/// Programmer errors and violated internal assumptions are deliberately
/// allowed to propagate.
final class SembastRateRepositoryImpl implements RateRepository {
  static final StoreRef<String, PersistenceRecord> _store = SembastStores.rates;

  final Database _database;

  /// Creates a rate repository using an already-open and validated [database].
  ///
  /// Database lifecycle ownership remains outside this repository. The
  /// repository never opens or closes the supplied database.
  // ignore: prefer_initializing_formals
  SembastRateRepositoryImpl({required Database database})
    : _database = database; // ignore: prefer_initializing_formals

  @override
  Future<Result<void, RateFailure>> create(Rate rate) =>
      guardPersistenceOperation<void, RateFailure>(
        operation: () => _database.transaction((transaction) async {
          final record = _store.record(rate.id.value);
          final existingRecord = await record.get(transaction);

          if (existingRecord != null) {
            return RateAlreadyExistsFailure(
              message: 'Rate ID already exists: ${rate.id.value}',
            );
          }

          final model = RatePersistenceModel.fromEntity(rate);

          await record.put(transaction, model.toRecord());

          return const Success(null);
        }),
        persistenceFailure: _persistenceFailure,
        failureMessage: 'Unable to create the rate.',
      );

  @override
  Future<Result<void, RateFailure>> createAll(List<Rate> rates) {
    if (rates.isEmpty) {
      return Future.value(const Success(null));
    }

    final validationFailure = _validateRequestedUniqueness(rates);

    if (validationFailure != null) {
      return Future.value(validationFailure);
    }

    return guardPersistenceOperation<void, RateFailure>(
      operation: () => _database.transaction((transaction) async {
        for (final rate in rates) {
          final existingRecord = await _store
              .record(rate.id.value)
              .get(transaction);

          if (existingRecord != null) {
            return RateAlreadyExistsFailure(
              message: 'Rate ID already exists: ${rate.id.value}',
            );
          }
        }

        for (final rate in rates) {
          final model = RatePersistenceModel.fromEntity(rate);

          await _store.record(rate.id.value).put(transaction, model.toRecord());
        }

        return const Success(null);
      }),
      persistenceFailure: _persistenceFailure,
      failureMessage: 'Unable to create the rates.',
    );
  }

  @override
  Future<Result<Rate, RateFailure>> getAtOrBefore({
    required AssetId baseAssetId,
    required AssetId quoteAssetId,
    required DateTime effectiveAt,
  }) => guardPersistenceOperation<Rate, RateFailure>(
    operation: () async {
      final requestedInstant = effectiveAt.toUtc();

      final rates = await _loadByPair(
        _database,
        baseAssetId: baseAssetId,
        quoteAssetId: quoteAssetId,
      );

      for (var index = rates.length - 1; index >= 0; index--) {
        final rate = rates[index];

        if (!rate.effectiveAt.isAfter(requestedInstant)) {
          return Success(rate);
        }
      }

      return RateNotFoundFailure(
        message: 'No rate was found at or before the requested instant.',
      );
    },
    persistenceFailure: _persistenceFailure,
    failureMessage:
        'Unable to load the rate at or before the requested instant.',
  );

  @override
  Future<Result<Rate, RateFailure>> getById(RateId id) =>
      guardPersistenceOperation<Rate, RateFailure>(
        operation: () async {
          final record = await _store.record(id.value).get(_database);

          if (record == null) {
            return RateNotFoundFailure(
              message: 'Rate ID was not found: ${id.value}',
            );
          }

          return Success(_rateFromRecord(recordKey: id.value, record: record));
        },
        persistenceFailure: _persistenceFailure,
        failureMessage: 'Unable to load the rate by ID.',
      );

  @override
  Future<Result<BatchLookup<Rate, RateId>, RateFailure>> getByIds(
    List<RateId> ids,
  ) => guardPersistenceOperation<BatchLookup<Rate, RateId>, RateFailure>(
    operation: () async {
      final requestedIds = <String>{};
      final requested = <RateId>[];

      for (final id in ids) {
        if (requestedIds.add(id.value)) {
          requested.add(id);
        }
      }

      final found = <Rate>[];
      final missing = <RateId>[];

      for (final id in requested) {
        final record = await _store.record(id.value).get(_database);

        if (record == null) {
          missing.add(id);
          continue;
        }

        found.add(_rateFromRecord(recordKey: id.value, record: record));
      }

      return Success(BatchLookup(found: found, missing: missing));
    },
    persistenceFailure: _persistenceFailure,
    failureMessage: 'Unable to load the rates by ID.',
  );

  @override
  Future<Result<List<Rate>, RateFailure>> getByPair({
    required AssetId baseAssetId,
    required AssetId quoteAssetId,
  }) => guardPersistenceOperation<List<Rate>, RateFailure>(
    operation: () async {
      final rates = await _loadByPair(
        _database,
        baseAssetId: baseAssetId,
        quoteAssetId: quoteAssetId,
      );

      return Success(List.unmodifiable(rates));
    },
    persistenceFailure: _persistenceFailure,
    failureMessage: 'Unable to load the rates for the requested asset pair.',
  );

  @override
  Future<Result<Rate, RateFailure>> getLatestByPair({
    required AssetId baseAssetId,
    required AssetId quoteAssetId,
  }) => guardPersistenceOperation<Rate, RateFailure>(
    operation: () async {
      final rates = await _loadByPair(
        _database,
        baseAssetId: baseAssetId,
        quoteAssetId: quoteAssetId,
      );

      if (rates.isEmpty) {
        return RateNotFoundFailure(
          message: 'No rate was found for the requested asset pair.',
        );
      }

      return Success(rates.last);
    },
    persistenceFailure: _persistenceFailure,
    failureMessage:
        'Unable to load the latest rate for the requested asset pair.',
  );

  /// Defines deterministic temporal ordering for rate observations.
  ///
  /// Financial time is the primary ordering criterion.
  ///
  /// Rate identity acts only as a stable tie-breaker when two observations
  /// have the same [Rate.effectiveAt].
  static int _compareRates(Rate first, Rate second) {
    final effectiveAtComparison = first.effectiveAt.compareTo(
      second.effectiveAt,
    );

    if (effectiveAtComparison != 0) {
      return effectiveAtComparison;
    }

    return first.id.value.compareTo(second.id.value);
  }

  /// Finds records for one exact ordered asset pair.
  ///
  /// Both fields participate in the filter because EUR/USD and USD/EUR have
  /// different economic meanings.
  static Future<List<RecordSnapshot<String, PersistenceRecord>>> _findByPair(
    DatabaseClient databaseClient, {
    required AssetId baseAssetId,
    required AssetId quoteAssetId,
  }) => _store.find(
    databaseClient,
    finder: Finder(
      filter: Filter.and(<Filter>[
        Filter.equals(RatePersistenceModel.baseAssetIdField, baseAssetId.value),
        Filter.equals(
          RatePersistenceModel.quoteAssetIdField,
          quoteAssetId.value,
        ),
      ]),
    ),
  );

  /// Loads every persisted observation for the exact ordered asset pair.
  ///
  /// Only records whose persisted base and quote identifiers exactly match the
  /// supplied pair are selected.
  ///
  /// The opposite pair is never queried.
  ///
  /// Reconstructed rates are ordered using domain timestamps rather than the
  /// serialized timestamp strings stored by Sembast.
  static Future<List<Rate>> _loadByPair(
    DatabaseClient databaseClient, {
    required AssetId baseAssetId,
    required AssetId quoteAssetId,
  }) async {
    final snapshots = await _findByPair(
      databaseClient,
      baseAssetId: baseAssetId,
      quoteAssetId: quoteAssetId,
    );

    final rates = snapshots.map(_rateFromSnapshot).toList();

    rates.sort(_compareRates);

    return rates;
  }

  /// Creates the feature-specific failure returned when persistence
  /// infrastructure cannot complete an operation.
  static RateRepositoryFailure _persistenceFailure(String message) =>
      RateRepositoryFailure(message: message);

  /// Reconstructs a domain rate from its record key and persisted value.
  static Rate _rateFromRecord({
    required String recordKey,
    required PersistenceRecord record,
  }) => RatePersistenceModel.fromRecord(
    recordKey: recordKey,
    record: record,
  ).toEntity();

  /// Reconstructs a domain rate from a Sembast snapshot.
  static Rate _rateFromSnapshot(
    RecordSnapshot<String, PersistenceRecord> snapshot,
  ) => _rateFromRecord(recordKey: snapshot.key, record: snapshot.value);

  /// Returns a failure when [rates] contains duplicate identities.
  ///
  /// This validation occurs before the database is touched because duplicate
  /// identities inside the requested batch are invalid independently of the
  /// current persisted state.
  static RateAlreadyExistsFailure? _validateRequestedUniqueness(
    List<Rate> rates,
  ) {
    final ids = <String>{};

    for (final rate in rates) {
      if (!ids.add(rate.id.value)) {
        return RateAlreadyExistsFailure(
          message: 'Rate ID is duplicated: ${rate.id.value}',
        );
      }
    }

    return null;
  }
}
