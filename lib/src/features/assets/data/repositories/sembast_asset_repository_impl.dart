import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record.dart';
import 'package:axiom/src/core/persistence/mapping/persistence_record_exception.dart';
import 'package:axiom/src/core/persistence/persistence_operation_guard.dart';
import 'package:axiom/src/core/persistence/sembast_stores.dart';
import 'package:axiom/src/core/repositories/batch_lookup.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/data/models/asset_persistence_model.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/assets/domain/failures/asset_already_exists_failure.dart';
import 'package:axiom/src/features/assets/domain/failures/asset_failure.dart';
import 'package:axiom/src/features/assets/domain/failures/asset_not_found_failure.dart';
import 'package:axiom/src/features/assets/domain/failures/asset_persistence_failure.dart';
import 'package:axiom/src/features/assets/domain/repositories/asset_repository.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_code.dart';
import 'package:sembast/sembast.dart';

/// Persists assets in the Sembast assets store.
///
/// The repository implements the domain-level [AssetRepository] contract while
/// keeping Sembast-specific persistence details inside the data layer.
///
/// Asset IDs are used as Sembast record keys. Asset codes remain persisted
/// fields because they are independently queryable and must also remain unique.
///
/// All multi-record writes are performed inside Sembast transactions so that
/// validation and mutation occur atomically.
///
/// Expected persistence exceptions are translated into
/// [AssetPersistenceFailure] by [guardPersistenceOperation]. Programmer errors
/// and violated internal assumptions are deliberately allowed to propagate.
final class SembastAssetRepositoryImpl implements AssetRepository {
  static final StoreRef<String, PersistenceRecord> _store =
      SembastStores.assets;

  final Database _database;

  /// Creates an asset repository using an already-open and validated
  /// [database].
  ///
  /// Database lifecycle ownership remains outside this repository. The
  /// repository never opens or closes the supplied database.
  // ignore: prefer_initializing_formals
  SembastAssetRepositoryImpl({required Database database})
    : _database = database; // ignore: prefer_initializing_formals

  @override
  Future<Result<Asset, AssetFailure>> create(Asset asset) =>
      guardPersistenceOperation<Asset, AssetFailure>(
        operation: () => _database.transaction((transaction) async {
          final record = _store.record(asset.id.value);
          final existingRecord = await record.get(transaction);

          if (existingRecord != null) {
            return AssetAlreadyExistsFailure(
              message: 'Asset ID already exists: ${asset.id.value}',
            );
          }

          final codeConflict = await _findCodeConflict(
            transaction,
            code: asset.code,
          );

          if (codeConflict != null) {
            return AssetAlreadyExistsFailure(
              message: 'Asset code already exists: ${asset.code.value}',
            );
          }

          final model = AssetPersistenceModel.fromEntity(asset);

          await record.put(transaction, model.toRecord());

          return Success(asset);
        }),
        persistenceFailure: _persistenceFailure,
        failureMessage: 'Unable to create the asset.',
      );

  @override
  Future<Result<List<Asset>, AssetFailure>> createAll(List<Asset> assets) {
    if (assets.isEmpty) {
      return Future.value(const Success(<Asset>[]));
    }

    final validationFailure = _validateRequestedUniqueness(assets);

    if (validationFailure != null) {
      return Future.value(validationFailure);
    }

    return guardPersistenceOperation<List<Asset>, AssetFailure>(
      operation: () => _database.transaction((transaction) async {
        for (final asset in assets) {
          final existingRecord = await _store
              .record(asset.id.value)
              .get(transaction);

          if (existingRecord != null) {
            return AssetAlreadyExistsFailure(
              message: 'Asset ID already exists: ${asset.id.value}',
            );
          }
        }

        for (final asset in assets) {
          final codeConflict = await _findCodeConflict(
            transaction,
            code: asset.code,
          );

          if (codeConflict != null) {
            return AssetAlreadyExistsFailure(
              message: 'Asset code already exists: ${asset.code.value}',
            );
          }
        }

        for (final asset in assets) {
          final model = AssetPersistenceModel.fromEntity(asset);

          await _store
              .record(asset.id.value)
              .put(transaction, model.toRecord());
        }

        return Success(List.unmodifiable(assets));
      }),
      persistenceFailure: _persistenceFailure,
      failureMessage: 'Unable to create the assets.',
    );
  }

  @override
  Future<Result<List<Asset>, AssetFailure>> getAll() =>
      guardPersistenceOperation<List<Asset>, AssetFailure>(
        operation: () async {
          final snapshots = await _store.find(_database);

          final assets = snapshots.map(_assetFromSnapshot).toList();

          return Success(List.unmodifiable(assets));
        },
        persistenceFailure: _persistenceFailure,
        failureMessage: 'Unable to load the assets.',
      );

  @override
  Future<Result<Asset?, AssetFailure>> getByCode(
    AssetCode code,
  ) => guardPersistenceOperation<Asset?, AssetFailure>(
    operation: () async {
      final snapshots = await _findByCode(_database, code);

      if (snapshots.isEmpty) {
        return const Success(null);
      }

      if (snapshots.length > 1) {
        throw const PersistenceRecordException(
          field: AssetPersistenceModel.codeField,
          reason:
              'Multiple persisted assets contain the same unique asset code.',
        );
      }

      return Success(_assetFromSnapshot(snapshots.single));
    },
    persistenceFailure: _persistenceFailure,
    failureMessage: 'Unable to load the asset by code.',
  );

  @override
  Future<Result<Asset?, AssetFailure>> getById(AssetId id) =>
      guardPersistenceOperation<Asset?, AssetFailure>(
        operation: () async {
          final record = await _store.record(id.value).get(_database);

          if (record == null) {
            return const Success(null);
          }

          return Success(_assetFromRecord(recordKey: id.value, record: record));
        },
        persistenceFailure: _persistenceFailure,
        failureMessage: 'Unable to load the asset by ID.',
      );

  @override
  Future<Result<BatchLookup<Asset, AssetId>, AssetFailure>> getByIds(
    List<AssetId> ids,
  ) => guardPersistenceOperation<BatchLookup<Asset, AssetId>, AssetFailure>(
    operation: () async {
      final requestedIds = <String>{};
      final requested = <AssetId>[];

      for (final id in ids) {
        if (requestedIds.add(id.value)) {
          requested.add(id);
        }
      }

      final found = <Asset>[];
      final missing = <AssetId>[];

      for (final id in requested) {
        final record = await _store.record(id.value).get(_database);

        if (record == null) {
          missing.add(id);
          continue;
        }

        found.add(_assetFromRecord(recordKey: id.value, record: record));
      }

      return Success(BatchLookup(found: found, missing: missing));
    },
    persistenceFailure: _persistenceFailure,
    failureMessage: 'Unable to load the assets by ID.',
  );

  @override
  Future<Result<Asset, AssetFailure>> update(Asset asset) =>
      guardPersistenceOperation<Asset, AssetFailure>(
        operation: () => _database.transaction((transaction) async {
          final record = _store.record(asset.id.value);
          final existingRecord = await record.get(transaction);

          if (existingRecord == null) {
            return AssetNotFoundFailure(
              message: 'Asset ID was not found: ${asset.id.value}',
            );
          }

          final codeConflict = await _findCodeConflict(
            transaction,
            code: asset.code,
            ignoredIds: {asset.id.value},
          );

          if (codeConflict != null) {
            return AssetAlreadyExistsFailure(
              message: 'Asset code already exists: ${asset.code.value}',
            );
          }

          final model = AssetPersistenceModel.fromEntity(asset);

          await record.put(transaction, model.toRecord());

          return Success(asset);
        }),
        persistenceFailure: _persistenceFailure,
        failureMessage: 'Unable to update the asset.',
      );

  @override
  Future<Result<List<Asset>, AssetFailure>> updateAll(List<Asset> assets) {
    if (assets.isEmpty) {
      return Future.value(const Success(<Asset>[]));
    }

    final validationFailure = _validateRequestedUniqueness(assets);

    if (validationFailure != null) {
      return Future.value(validationFailure);
    }

    return guardPersistenceOperation<List<Asset>, AssetFailure>(
      operation: () => _database.transaction((transaction) async {
        final missing = <AssetId>[];

        for (final asset in assets) {
          final existingRecord = await _store
              .record(asset.id.value)
              .get(transaction);

          if (existingRecord == null) {
            missing.add(asset.id);
          }
        }

        if (missing.isNotEmpty) {
          final missingIds = missing.map((id) => id.value).join(', ');

          return AssetNotFoundFailure(
            message: 'Asset IDs were not found: $missingIds',
          );
        }

        final updatedIds = assets.map((asset) => asset.id.value).toSet();

        for (final asset in assets) {
          final codeConflict = await _findCodeConflict(
            transaction,
            code: asset.code,
            ignoredIds: updatedIds,
          );

          if (codeConflict != null) {
            return AssetAlreadyExistsFailure(
              message: 'Asset code already exists: ${asset.code.value}',
            );
          }
        }

        for (final asset in assets) {
          final model = AssetPersistenceModel.fromEntity(asset);

          await _store
              .record(asset.id.value)
              .put(transaction, model.toRecord());
        }

        return Success(List.unmodifiable(assets));
      }),
      persistenceFailure: _persistenceFailure,
      failureMessage: 'Unable to update the assets.',
    );
  }

  /// Returns a failure when [assets] contains duplicate IDs or codes.
  ///
  /// This validation happens before touching the database because duplicates
  /// inside the requested batch are invalid independently of persisted state.
  static AssetAlreadyExistsFailure? _validateRequestedUniqueness(
    List<Asset> assets,
  ) {
    final ids = <String>{};
    final codes = <String>{};

    for (final asset in assets) {
      if (!ids.add(asset.id.value)) {
        return AssetAlreadyExistsFailure(
          message: 'Asset ID is duplicated: ${asset.id.value}',
        );
      }

      if (!codes.add(asset.code.value)) {
        return AssetAlreadyExistsFailure(
          message: 'Asset code is duplicated: ${asset.code.value}',
        );
      }
    }

    return null;
  }

  /// Finds all persisted records using [code].
  ///
  /// More than one result indicates invalid persisted state because asset
  /// codes are unique according to the repository contract.
  static Future<List<RecordSnapshot<String, PersistenceRecord>>> _findByCode(
    DatabaseClient databaseClient,
    AssetCode code,
  ) => _store.find(
    databaseClient,
    finder: Finder(
      filter: Filter.equals(AssetPersistenceModel.codeField, code.value),
    ),
  );

  /// Finds a persisted asset using [code] whose record key is not ignored.
  ///
  /// [ignoredIds] is used by updates so that an asset does not conflict with
  /// itself. Bulk updates ignore all records participating in the batch,
  /// allowing valid code swaps between those records.
  static Future<RecordSnapshot<String, PersistenceRecord>?> _findCodeConflict(
    DatabaseClient databaseClient, {
    required AssetCode code,
    Set<String> ignoredIds = const {},
  }) async {
    final snapshots = await _findByCode(databaseClient, code);

    for (final snapshot in snapshots) {
      if (!ignoredIds.contains(snapshot.key)) {
        return snapshot;
      }
    }

    return null;
  }

  /// Reconstructs a domain asset from a Sembast snapshot.
  static Asset _assetFromSnapshot(
    RecordSnapshot<String, PersistenceRecord> snapshot,
  ) {
    return _assetFromRecord(recordKey: snapshot.key, record: snapshot.value);
  }

  /// Reconstructs a domain asset from its record key and persisted value.
  static Asset _assetFromRecord({
    required String recordKey,
    required PersistenceRecord record,
  }) {
    return AssetPersistenceModel.fromRecord(
      recordKey: recordKey,
      record: record,
    ).toEntity();
  }

  /// Creates the feature-specific failure returned when persistence
  /// infrastructure cannot complete an operation.
  static AssetPersistenceFailure _persistenceFailure(String message) {
    return AssetPersistenceFailure(message: message);
  }
}
