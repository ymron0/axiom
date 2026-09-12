import 'package:axiom/src/core/repositories/batch_lookup.dart';
import 'package:axiom/src/core/result/result.dart';
import 'package:axiom/src/features/assets/domain/entities/asset.dart';
import 'package:axiom/src/features/assets/domain/failures/asset_already_exists_failure.dart';
import 'package:axiom/src/features/assets/domain/failures/asset_failure.dart';
import 'package:axiom/src/features/assets/domain/failures/asset_not_found_failure.dart';
import 'package:axiom/src/features/assets/domain/repositories/asset_repository.dart';
import 'package:axiom/src/features/assets/domain/value_objects/asset_code.dart';
import 'package:axiom/src/core/identity/ids/asset_id.dart';
import 'package:fixtures/fixtures.dart';

/// Stores assets in memory.
///
/// Example: `final repository = InMemoryAssetRepositoryImpl();`
final class InMemoryAssetRepositoryImpl implements AssetRepository {
  /// Creates a repository seeded with [initialAssets].
  ///
  /// When omitted, the repository loads the external asset fixtures. Throws
  /// [ArgumentError] when the seed contains duplicate IDs or codes.
  InMemoryAssetRepositoryImpl({Iterable<Asset>? initialAssets})
    : _assets = _validatedSeed(
        initialAssets ??
            assetsFixtures
                .map<Asset>(
                  (fixture) => Currency(
                    id: AssetId.fromString(fixture.id),
                    name: fixture.name,
                    code: AssetCode(fixture.code.value),
                    symbol: fixture.symbol,
                    decimalPlaces: fixture.decimalPlaces,
                    remoteLogoUrl: fixture.remoteLogoUrl,
                    bundledLogoAsset: fixture.bundledLogoAsset,
                  ),
                )
                .toList(),
      );

  final List<Asset> _assets;

  static List<Asset> _validatedSeed(Iterable<Asset> assets) {
    final copiedAssets = assets.toList();
    final ids = <String>{};
    final codes = <String>{};

    for (final asset in copiedAssets) {
      if (!ids.add(asset.id.value)) {
        throw ArgumentError('Asset ID is duplicated: ${asset.id.value}');
      }
      if (!codes.add(asset.code.value)) {
        throw ArgumentError('Asset code is duplicated: ${asset.code.value}');
      }
    }

    return copiedAssets;
  }

  @override
  Future<Result<Asset, AssetFailure>> create(Asset asset) async {
    if (_assets.any((storedAsset) => storedAsset.id == asset.id)) {
      return AssetAlreadyExistsFailure(
        message: 'Asset ID already exists: ${asset.id.value}',
      );
    }
    if (_assets.any((storedAsset) => storedAsset.code == asset.code)) {
      return AssetAlreadyExistsFailure(
        message: 'Asset code already exists: ${asset.code.value}',
      );
    }

    _assets.add(asset);
    return Success(asset);
  }

  @override
  Future<Result<List<Asset>, AssetFailure>> createAll(
    List<Asset> assets,
  ) async {
    final requestedIds = <String>{};
    final requestedCodes = <String>{};
    for (final asset in assets) {
      if (!requestedIds.add(asset.id.value)) {
        return AssetAlreadyExistsFailure(
          message: 'Asset ID is duplicated: ${asset.id.value}',
        );
      }
      if (!requestedCodes.add(asset.code.value)) {
        return AssetAlreadyExistsFailure(
          message: 'Asset code is duplicated: ${asset.code.value}',
        );
      }
    }

    final lookup = _lookupByIds(assets.map((asset) => asset.id).toList());
    if (lookup.found.isNotEmpty) {
      return AssetAlreadyExistsFailure(
        message: 'Asset ID already exists: ${lookup.found.first.id.value}',
      );
    }
    if (_assets.any(
      (storedAsset) => requestedCodes.contains(storedAsset.code.value),
    )) {
      final duplicate = _assets.firstWhere(
        (storedAsset) => requestedCodes.contains(storedAsset.code.value),
      );
      return AssetAlreadyExistsFailure(
        message: 'Asset code already exists: ${duplicate.code.value}',
      );
    }

    _assets.addAll(assets);
    return Success(List.unmodifiable(assets));
  }

  @override
  Future<Result<List<Asset>, AssetFailure>> getAll() async {
    return Success(List.unmodifiable(_assets));
  }

  @override
  Future<Result<List<Asset>, AssetFailure>> getByCode(AssetCode code) async {
    final matchingAssets = _assets
        .where((asset) => asset.code.value == code.value)
        .toList();

    return Success(List.unmodifiable(matchingAssets));
  }

  @override
  Future<Result<Asset?, AssetFailure>> getById(AssetId id) async {
    for (final asset in _assets) {
      if (asset.id.value == id.value) {
        return Success(asset);
      }
    }

    return const Success(null);
  }

  @override
  Future<Result<BatchLookup<Asset, AssetId>, AssetFailure>> getByIds(
    List<AssetId> ids,
  ) async {
    return Success(_lookupByIds(ids));
  }

  @override
  Future<Result<Asset, AssetFailure>> update(Asset asset) async {
    final index = _assets.indexWhere(
      (storedAsset) => storedAsset.id.value == asset.id.value,
    );
    if (index == -1) {
      return AssetNotFoundFailure(
        message: 'Asset ID was not found: ${asset.id.value}',
      );
    }
    if (_assets.any(
      (storedAsset) =>
          storedAsset.id != asset.id && storedAsset.code == asset.code,
    )) {
      return AssetAlreadyExistsFailure(
        message: 'Asset code already exists: ${asset.code.value}',
      );
    }

    _assets[index] = asset;
    return Success(asset);
  }

  @override
  Future<Result<List<Asset>, AssetFailure>> updateAll(
    List<Asset> assets,
  ) async {
    final requestedIds = <String>{};
    final requestedCodes = <String>{};
    for (final asset in assets) {
      if (!requestedIds.add(asset.id.value)) {
        return AssetAlreadyExistsFailure(
          message: 'Asset ID is duplicated: ${asset.id.value}',
        );
      }
      if (!requestedCodes.add(asset.code.value)) {
        return AssetAlreadyExistsFailure(
          message: 'Asset code is duplicated: ${asset.code.value}',
        );
      }
    }

    final lookup = _lookupByIds(assets.map((asset) => asset.id).toList());
    if (lookup.missing.isNotEmpty) {
      final missingIds = lookup.missing.map((id) => id.value).join(', ');
      return AssetNotFoundFailure(
        message: 'Asset IDs were not found: $missingIds',
      );
    }
    if (_assets.any(
      (storedAsset) =>
          !requestedIds.contains(storedAsset.id.value) &&
          requestedCodes.contains(storedAsset.code.value),
    )) {
      final duplicate = _assets.firstWhere(
        (storedAsset) =>
            !requestedIds.contains(storedAsset.id.value) &&
            requestedCodes.contains(storedAsset.code.value),
      );
      return AssetAlreadyExistsFailure(
        message: 'Asset code already exists: ${duplicate.code.value}',
      );
    }

    for (final asset in assets) {
      final index = _assets.indexWhere(
        (storedAsset) => storedAsset.id.value == asset.id.value,
      );
      _assets[index] = asset;
    }

    return Success(List.unmodifiable(assets));
  }

  BatchLookup<Asset, AssetId> _lookupByIds(List<AssetId> ids) {
    final requestedIds = <String>{};
    final requested = <AssetId>[];
    for (final id in ids) {
      if (requestedIds.add(id.value)) {
        requested.add(id);
      }
    }

    final found = _assets
        .where((asset) => requestedIds.contains(asset.id.value))
        .toList();
    final foundIds = found.map((asset) => asset.id.value).toSet();
    final missing = requested
        .where((id) => !foundIds.contains(id.value))
        .toList();

    return BatchLookup(found: found, missing: missing);
  }
}
