import 'package:axiom/src/core/di/validated_database_provider.dart';
import 'package:axiom/src/features/jars/data/repositories/sembast_jar_repository_impl.dart';
import 'package:axiom/src/features/jars/domain/repositories/jar_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'jar_repository_provider.g.dart';

/// Provides the persistent repository used by the jars feature.
///
/// The database must already have completed the validated persistence
/// lifecycle before this provider is resolved.
@Riverpod(keepAlive: true)
JarRepository jarRepository(Ref ref) {
  return SembastJarRepositoryImpl(
    database: ref.watch(validatedDatabaseProvider),
  );
}
