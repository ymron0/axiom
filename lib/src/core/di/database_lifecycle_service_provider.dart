import 'package:axiom/src/core/di/sembast_database_provider.dart';
import 'package:axiom/src/core/persistence/database_lifecycle_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'database_lifecycle_service_provider.g.dart';

/// Provides the application-scoped database lifecycle coordinator.
///
/// Dependency injection only constructs the lifecycle service.
///
/// Opening, closing, integrity validation, and recovery remain explicit
/// operations owned by [DatabaseLifecycleService].
@Riverpod(keepAlive: true)
DatabaseLifecycleService databaseLifecycleService(Ref ref) {
  return DatabaseLifecycleService(database: ref.watch(sembastDatabaseProvider));
}
