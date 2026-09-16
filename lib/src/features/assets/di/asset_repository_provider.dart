import 'package:axiom/src/core/di/validated_database_provider.dart';
import 'package:axiom/src/features/assets/data/repositories/sembast_asset_repository_impl.dart';
import 'package:axiom/src/features/assets/domain/repositories/asset_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'asset_repository_provider.g.dart';

/// Provides the persistent repository used by the assets feature.
///
/// The database must already have completed the validated persistence
/// lifecycle before this provider is resolved.
@Riverpod(keepAlive: true)
AssetRepository assetRepository(Ref ref) {
  return SembastAssetRepositoryImpl(
    database: ref.watch(validatedDatabaseProvider),
  );
}
