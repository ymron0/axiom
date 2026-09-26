import 'package:axiom/src/features/jars/application/queries/jar_watch_queries.dart';
import 'package:axiom/src/features/jars/di/jar_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'jar_watch_queries_provider.g.dart';

/// Provides reactive jar queries backed by the configured repository.
@riverpod
JarWatchQueries jarWatchQueries(Ref ref) {
  return JarWatchQueries(ref.watch(jarRepositoryProvider));
}
