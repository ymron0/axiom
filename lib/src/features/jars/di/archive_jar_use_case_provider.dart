import 'package:axiom/src/core/di/clock_provider.dart';
import 'package:axiom/src/features/jars/application/use_cases/archive_jar_use_case.dart';
import 'package:axiom/src/features/jars/di/jar_repository_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'archive_jar_use_case_provider.g.dart';

/// Provides the use case for archiving a jar.
@riverpod
ArchiveJarUseCase archiveJarUseCase(Ref ref) {
  return ArchiveJarUseCase(
    repository: ref.watch(jarRepositoryProvider),
    clock: ref.watch(clockProvider),
  );
}
