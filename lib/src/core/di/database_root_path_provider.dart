import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'database_root_path_provider.g.dart';

/// Provides the root directory containing the persistent database.
///
/// This provider is an application configuration boundary.
///
/// Production bootstrap must override it with a platform-resolved persistent
/// directory before any database infrastructure is resolved.
///
/// Keeping path resolution outside the persistence layer prevents persistence
/// infrastructure from depending directly on Flutter platform plugins and
/// allows tests to inject isolated temporary locations.
@Riverpod(keepAlive: true)
String databaseRootPath(Ref ref) {
  throw StateError(
    'databaseRootPathProvider must be overridden during application bootstrap.',
  );
}
