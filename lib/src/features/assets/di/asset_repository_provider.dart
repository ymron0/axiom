import 'package:axiom/src/features/assets/data/repositories/in_memory_asset_repository_impl.dart';
import 'package:axiom/src/features/assets/domain/repositories/asset_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'asset_repository_provider.g.dart';

/// Provides the asset repository used by the assets feature.
@riverpod
AssetRepository assetRepository(Ref ref) {
  return InMemoryAssetRepositoryImpl();
}
