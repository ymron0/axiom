import 'package:axiom/src/features/jars/application/use_cases/restore_jar_use_case.dart';
import 'package:axiom/src/features/jars/di/jar_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'restore_jar_use_case_provider.g.dart';

/// Provides the use case for restoring a deleted jar.
@riverpod
RestoreJarUseCase restoreJarUseCase(Ref ref) {
  return RestoreJarUseCase(ref.watch(jarRepositoryProvider));
}
