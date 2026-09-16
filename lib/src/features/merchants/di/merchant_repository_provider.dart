import 'package:axiom/src/core/di/validated_database_provider.dart';
import 'package:axiom/src/features/merchants/data/repositories/sembast_merchant_repository_impl.dart';
import 'package:axiom/src/features/merchants/domain/repositories/merchant_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'merchant_repository_provider.g.dart';

/// Provides the persistent repository used by the merchants feature.
///
/// The database must already have completed the validated persistence
/// lifecycle before this provider is resolved.
@Riverpod(keepAlive: true)
MerchantRepository merchantRepository(Ref ref) {
  return SembastMerchantRepositoryImpl(
    database: ref.watch(validatedDatabaseProvider),
  );
}
