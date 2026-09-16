import 'package:axiom/src/core/di/database_lifecycle_service_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sembast/sembast.dart';

part 'validated_database_provider.g.dart';

/// Provides the database instance that has successfully completed the
/// persistence lifecycle open and integrity-validation sequence.
///
/// This provider deliberately does not open the database.
///
/// Application bootstrap must successfully open the
/// `DatabaseLifecycleService` before any persistent repository provider is
/// resolved.
///
/// Keeping this boundary synchronous allows domain repository providers and
/// their dependent use-case providers to remain synchronous.
@Riverpod(keepAlive: true)
Database validatedDatabase(Ref ref) {
  final lifecycleService = ref.watch(databaseLifecycleServiceProvider);
  final database = lifecycleService.validatedDatabaseOrNull;

  if (database == null) {
    throw StateError(
      'validatedDatabaseProvider requires the database lifecycle to be '
      'opened successfully before persistent repositories are resolved.',
    );
  }

  return database;
}
