import 'package:axiom/src/core/di/validated_database_provider.dart';
import 'package:axiom/src/features/custodians/data/repositories/sembast_custodian_repository_impl.dart';
import 'package:axiom/src/features/custodians/domain/repositories/custodian_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'custodian_repository_provider.g.dart';

/// Provides the persistent repository used by the custodians feature.
///
/// The database must already have completed the validated persistence
/// lifecycle before this provider is resolved.
@Riverpod(keepAlive: true)
CustodianRepository custodianRepository(Ref ref) {
  return SembastCustodianRepositoryImpl(
    database: ref.watch(validatedDatabaseProvider),
  );
}
