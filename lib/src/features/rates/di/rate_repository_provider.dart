import 'package:axiom/src/core/di/validated_database_provider.dart';
import 'package:axiom/src/features/rates/data/repositories/sembast_rate_repository_impl.dart';
import 'package:axiom/src/features/rates/domain/repositories/rate_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'rate_repository_provider.g.dart';

/// Provides the persistent repository used by the rates feature.
///
/// The database must already have completed the validated persistence
/// lifecycle before this provider is resolved.
@Riverpod(keepAlive: true)
RateRepository rateRepository(Ref ref) {
  return SembastRateRepositoryImpl(
    database: ref.watch(validatedDatabaseProvider),
  );
}
