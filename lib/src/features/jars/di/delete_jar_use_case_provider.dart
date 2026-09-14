import 'package:axiom/src/features/jars/application/use_cases/delete_jar_use_case.dart';
import 'package:axiom/src/features/jars/di/jar_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'delete_jar_use_case_provider.g.dart';

/// Provides the feature-local use case for deleting a jar.
@riverpod
DeleteJarUseCase deleteJarUseCase(Ref ref) {
  return DeleteJarUseCase(ref.watch(jarRepositoryProvider));
}
