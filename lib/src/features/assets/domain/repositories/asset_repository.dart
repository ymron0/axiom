// coverage:ignore-file

import 'package:axiom/src/core/failures/base_failure.dart';
import 'package:axiom/src/core/failures/record_already_exists_failure.dart';
import 'package:axiom/src/core/failures/record_not_found_failure.dart';
import 'package:axiom/src/core/repositories/batch_lookup.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_code.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_id.dart';

/// Repository interface for managing assets.
///
/// Provides methods for creating, retrieving, and updating assets.
abstract interface class AssetRepository {
  /// Stores [asset] when its ID is not already present.
  ///
  /// Returns [RecordAlreadyExistsFailure] when another asset has the same ID.
  /// Example: `final result = await repository.create(asset);`
  Future<Result<Asset, BaseFailure>> create(Asset asset);

  /// Stores all [assets] when their IDs are unique and not already present.
  ///
  /// The operation is atomic. Returns [RecordAlreadyExistsFailure] when an ID
  /// is duplicated in [assets] or already exists in the repository.
  ///
  /// An empty [assets] list succeeds with an empty result.
  /// Example: `final result = await repository.createAll(assets);`
  Future<Result<List<Asset>, BaseFailure>> createAll(List<Asset> assets);

  /// Returns every asset currently stored in the repository.
  /// Example: `final result = await repository.getAll();`
  Future<Result<List<Asset>, BaseFailure>> getAll();

  /// Returns the asset identified by [id], or `null` when it is not found.
  /// Example: `final result = await repository.getById(assetId);`
  Future<Result<Asset?, BaseFailure>> getById(AssetId id);

  /// Returns every asset with the requested [code].
  ///
  /// Returns an empty list when no asset has the requested code.
  /// Example: `final result = await repository.getByCode(assetCode);`
  Future<Result<List<Asset>, BaseFailure>> getByCode(AssetCode code);

  /// Returns found assets and the requested IDs that are missing.
  ///
  /// Duplicate requested IDs are reported once, in their first-seen order.
  /// Example: `final result = await repository.getByIds(assetIds);`
  Future<Result<BatchLookup<Asset, AssetId>, BaseFailure>> getByIds(
    List<AssetId> ids,
  );

  /// Replaces the stored asset with [asset] using its ID as the identity.
  ///
  /// Returns [RecordNotFoundFailure] when no stored asset has the same ID.
  /// Example: `final result = await repository.update(updatedAsset);`
  Future<Result<Asset, BaseFailure>> update(Asset asset);

  /// Replaces all stored assets identified by [assets].
  ///
  /// Asset IDs in [assets] must be unique. The operation is atomic: when any
  /// asset ID is missing, no assets are changed. Returns
  /// [RecordAlreadyExistsFailure] when an ID is duplicated in [assets],
  /// [RecordNotFoundFailure] when one or more IDs are missing, or another
  /// [BaseFailure] when the lookup fails.
  ///
  /// An empty [assets] list succeeds with an empty result.
  /// Example: `final result = await repository.updateAll(updatedAssets);`
  Future<Result<List<Asset>, BaseFailure>> updateAll(List<Asset> assets);
}
