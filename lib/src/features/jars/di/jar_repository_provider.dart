import 'package:axiom/src/features/jars/data/repositories/in_memory_jar_repository_impl.dart';
import 'package:axiom/src/features/jars/domain/repositories/jar_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'jar_repository_provider.g.dart';

/// Provides the repository used by the jars feature.
@riverpod
JarRepository jarRepository(Ref ref) {
  return InMemoryJarRepositoryImpl();
}
