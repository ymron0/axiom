// coverage:ignore-file

import 'package:axiom/src/core/repositories/batch_lookup.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/assets/domain/failures/asset_already_exists_failure.dart';
import 'package:axiom/src/features/assets/domain/failures/asset_failure.dart';
import 'package:axiom/src/features/assets/domain/failures/asset_not_found_failure.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_code.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';

/// Repository interface for managing assets.
///
/// Provides methods for creating, retrieving, and updating assets.
abstract interface class AssetRepository {
  /// Stores [asset] when its ID and code are not already present.
  ///
  /// Returns [AssetAlreadyExistsFailure] when another asset has the same ID
  /// or code.
  /// Example: `final result = await repository.create(asset);`
  Future<Result<Asset, AssetFailure>> create(Asset asset);

  /// Stores all [assets] when their IDs and codes are unique and not already
  /// present.
  ///
  /// The operation is atomic. Returns [AssetAlreadyExistsFailure] when an ID
  /// is duplicated in [assets] or already exists in the repository.
  ///
  /// Duplicate IDs or codes within [assets], or IDs or codes already present
  /// in the repository, fail the operation without storing any asset.
  /// An empty [assets] list succeeds with an empty result.
  /// Example: `final result = await repository.createAll(assets);`
  Future<Result<List<Asset>, AssetFailure>> createAll(List<Asset> assets);

  /// Returns every asset currently stored in the repository.
  /// Example: `final result = await repository.getAll();`
  Future<Result<List<Asset>, AssetFailure>> getAll();

  /// Returns every asset with the requested [code].
  ///
  /// Returns an empty list when no asset has the requested code.
  /// Example: `final result = await repository.getByCode(assetCode);`
  Future<Result<List<Asset>, AssetFailure>> getByCode(AssetCode code);

  /// Returns the asset identified by [id], or `null` when it is not found.
  /// Example: `final result = await repository.getById(assetId);`
  Future<Result<Asset?, AssetFailure>> getById(AssetId id);

  /// Returns found assets and the requested IDs that are missing.
  ///
  /// Duplicate requested IDs are reported once, in their first-seen order.
  /// Example: `final result = await repository.getByIds(assetIds);`
  Future<Result<BatchLookup<Asset, AssetId>, AssetFailure>> getByIds(
    List<AssetId> ids,
  );

  /// Replaces the stored asset with [asset] using its ID as the identity.
  ///
  /// Returns [AssetNotFoundFailure] when no stored asset has the same ID and
  /// [AssetAlreadyExistsFailure] when its code belongs to another asset.
  /// Example: `final result = await repository.update(updatedAsset);`
  Future<Result<Asset, AssetFailure>> update(Asset asset);

  /// Replaces all stored assets identified by [assets].
  ///
  /// Asset IDs in [assets] must be unique. The operation is atomic: when any
  /// asset ID is missing, no assets are changed. Returns
  /// [AssetAlreadyExistsFailure] when an ID is duplicated in [assets],
  /// when codes are duplicated in [assets], or when an updated code belongs to
  /// another stored asset,
  /// [AssetNotFoundFailure] when one or more IDs are missing.
  ///
  /// An empty [assets] list succeeds with an empty result.
  /// Example: `final result = await repository.updateAll(updatedAssets);`
  Future<Result<List<Asset>, AssetFailure>> updateAll(List<Asset> assets);
}
