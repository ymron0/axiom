import 'package:axiom/src/features/jars/application/use_cases/update_jar_use_case.dart';
import 'package:axiom/src/features/jars/di/jar_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'update_jar_use_case_provider.g.dart';

/// Provides the use case for updating a jar.
@riverpod
UpdateJarUseCase updateJarUseCase(Ref ref) {
  return UpdateJarUseCase(ref.watch(jarRepositoryProvider));
}
