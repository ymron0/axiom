import 'package:axiom/src/core/di/clock_provider.dart';
import 'package:axiom/src/features/jars/application/use_cases/unarchive_jar_use_case.dart';
import 'package:axiom/src/features/jars/di/jar_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'unarchive_jar_use_case_provider.g.dart';

/// Provides the use case for unarchiving a jar.
@riverpod
UnarchiveJarUseCase unarchiveJarUseCase(Ref ref) {
  return UnarchiveJarUseCase(
    repository: ref.watch(jarRepositoryProvider),
    clock: ref.watch(clockProvider),
  );
}
